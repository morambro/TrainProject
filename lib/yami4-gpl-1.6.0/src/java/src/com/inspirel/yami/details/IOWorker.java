// Copyright Maciej Sobczak 2008-2012.
// This file is part of YAMI4.
//
// YAMI4 is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// YAMI4 is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with YAMI4.  If not, see <http://www.gnu.org/licenses/>.

package com.inspirel.yami.details;

import com.inspirel.yami.ConnectionEventCallback;
import com.inspirel.yami.LogCallback;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.SelectionKey;
import java.nio.channels.Selector;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

public class IOWorker implements Runnable {

    private final Map<String, Channel> channels;
    private final Map<String, Listener> listeners;
    private final WaterFlowManager incomingFlowManager;
    private final Options options;
    private final IncomingMessageDispatchCallback
            incomingMessageDispatchCallback;
    private final ConnectionEventCallback connectionEventCallback;
    private final LogCallback logCallback;
    private final LogCallback.LogLevel logLevel;

    private final Map<SelectionKey, Listener> listenersForSelection;
            
    private final Map<SelectionKey, Channel> channelsForSelection;

    private boolean stopRequest;
    
    private Selector selector;
    
    public IOWorker(Map<String, Channel> channels,
            Map<String, Listener> listeners,
            WaterFlowManager incomingFlowManager,
            Options options,
            IncomingMessageDispatchCallback incomingMessageDispatchCallback,
            ConnectionEventCallback connectionEventCallback,
            LogCallback logCallback, LogCallback.LogLevel logLevel) {
        
        this.channels = channels;
        this.listeners = listeners;
        this.incomingFlowManager = incomingFlowManager;
        this.options = options;
        this.incomingMessageDispatchCallback =
                incomingMessageDispatchCallback;
        this.connectionEventCallback = connectionEventCallback;
        this.logCallback = logCallback;
        this.logLevel = logLevel;

        listenersForSelection = new HashMap<SelectionKey, Listener>();
        channelsForSelection = new HashMap<SelectionKey, Channel>();
        
        stopRequest = false;
    }
    
    public void wakeup() {
        synchronized (this) {
            if (selector != null) {
                selector.wakeup();
            }
        }
    }
    
    public void requestStop() {
        synchronized (this) {
            stopRequest = true;
            if (selector != null) {
                selector.wakeup();
            }
        }
    }
    
    private void openSelector() {
        try {
            synchronized (this) {
                selector = Selector.open();
                if (stopRequest) {
                    selector.wakeup();
                }
            }
        } catch (IOException ex) {
            // ignore
        }
    }

    private void closeSelector() {
        try {
            synchronized (this) {
                for (SelectionKey key : selector.keys()) {
                    key.cancel();
                }
                selector.selectNow();
                selector.close();
                selector = null;
            }
        } catch (IOException ex) {
            // ignore, will never happen
        }
    }
    
    private void registerListenersAndChannels() {

        listenersForSelection.clear();
        channelsForSelection.clear();

        // flow control:
        // the outgoing traffic is controlled at the level of
        // send/send_one_way functions - that is, even before the message
        // reaches the transport layer and so the output at the transport
        // layer is always enabled
        // the incoming traffic is controlled at the transport level,
        // depending on the length of the incoming message queue
        // which is managed by the agent and its dispatch manager
        
        final boolean allowOutput = true;
        final boolean allowInput = incomingFlowManager.isAllowed();

        synchronized (listeners) {
            for (Map.Entry<String, Listener> e : listeners.entrySet()) {
                Listener lst = e.getValue();
                    
                SelectionKey key = lst.registerForSelection(selector);
                listenersForSelection.put(key, lst);
            }
        }

        synchronized (channels) {
            for (Map.Entry<String, Channel> e : channels.entrySet()) {
                Channel ch = e.getValue();

                SelectionKey key = ch.registerForSelection(
                        selector, allowInput, allowOutput);
                    
                if (key != null) {
                    channelsForSelection.put(key, ch);
                }
            }
        }
    }
    
    private void waitUntilReady() {
        try {
            selector.select();
        } catch (IOException ex) {
            // ignore, will never happen
        }
    }
    
    private void reportChannelEvent(String name,
            ConnectionEventCallback.ConnectionEvent event) {
        if (connectionEventCallback != null) {
            try {
                connectionEventCallback.report(name, event);
            } catch (Exception e) {
                // ignore exceptions from user code
            }
        }
    }
    
    private void reportNewIncomingChannel(String name) {
        reportChannelEvent(name,
                ConnectionEventCallback.ConnectionEvent.
                NEW_INCOMING_CONNECTION);
    }
    
    private void useReadyListener(Listener lst) {
        try {
            Listener.ListeningResult listenResult = lst.accept();
            String target;
            if (listenResult.channel != null) {
                // a new channel was accepted by the listener

                Channel acceptedChannel = listenResult.channel;
                target = acceptedChannel.getTarget();
            
                synchronized (channels) {
                    channels.put(target, acceptedChannel);
                }
                
                reportNewIncomingChannel(target);
                
            } else {
                // a full frame was accepted by the listener

                target = listenResult.target;
                ByteBuffer buffer = listenResult.buffer;
                Channel ch;
                synchronized (channels) {
                    ch = channels.get(target);
                    if (ch == null) {
                        // no such channel, create it
                        ch = new Channel(target, options,
                                incomingMessageDispatchCallback,
                                logCallback, logLevel);
                        channels.put(target, ch);
                    }
                }

                // appropriate channel already exists
                // -> inject the frame there

                ch.injectFullFrame(buffer);
            }
        } catch (Exception ex) {
            
            // close the listener
            
            synchronized (listeners) {
                lst.close();
                
                String resolvedTarget = lst.getResolvedTarget();
                
                listeners.remove(resolvedTarget);
            }
        }
    }
    
    private void useReadyChannel(Channel ch,
            boolean doInput, boolean doOutput) {
        
        try {
            ch.doSomeWork(doInput, doOutput);
        } catch (Exception ex) {
                        
            // in case of error during I/O operation
            // on any channel, close it and abandon
            // all incoming and outgoing messages
            // that are in this channel's queues
                        
            synchronized (channels) {
                ch.close();

                String target = ch.getTarget();

                channels.remove(target);

                reportChannelEvent(target,
                        ConnectionEventCallback.ConnectionEvent.
                        CONNECTION_CLOSED);
            }
        }
    }
    
    private void useReadyListenersAndChannels() {
        
        Iterator<SelectionKey> it = selector.selectedKeys().iterator();
        while (it.hasNext()) {
            SelectionKey key = it.next();
                
            // remove this key from the selected set
            it.remove();

            final int operations = key.readyOps();
            
            final boolean doAccept =
                    (operations & SelectionKey.OP_ACCEPT) != 0;
            if (doAccept) {
                Listener lst = listenersForSelection.get(key);
                useReadyListener(lst);
            }
            
            final boolean doInput =
                    (operations & SelectionKey.OP_READ) != 0;
            final boolean doOutput =
                    (operations & SelectionKey.OP_WRITE) != 0;
                
            if (doInput || doOutput) {
                Channel ch = channelsForSelection.get(key);

                if (ch != null) {
                    useReadyChannel(ch, doInput, doOutput);
                } else {
                    // if the channel was not found in the channel set,
                    // it might be because it was actually a UDP channel
                    // working as a listener - in which case its operation
                    // is OP_READ, but it was added to the listener set

                    Listener lst = listenersForSelection.get(key);
                    useReadyListener(lst);
                }
            }
        }
    }
    
    @Override
    public void run() {
        boolean finished = false;
        while (finished == false) {
            
            openSelector();
            
            registerListenersAndChannels();
            
            waitUntilReady();
            
            useReadyListenersAndChannels();

            closeSelector();
            
            synchronized (this) {
                finished = stopRequest;
            }
        }
    }
}

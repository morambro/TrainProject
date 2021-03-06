#include <yami4-core/agent.h>
#include <yami4-core/parameters.h>

#include <cassert>
#include <cstdlib>
#include <cstring>
#include <iostream>

using namespace yami::core;

void dispatch_function(
    void * hint,
    const char * source,
    const char * /* header_buffers */ [],
    std::size_t /* header_buffer_sizes */ [],
    std::size_t /* num_of_header_buffers */,
    const char * body_buffers[],
    std::size_t body_buffer_sizes[],
    std::size_t num_of_body_buffers)
{
    agent * server_agent = static_cast<agent *>(hint);

    // ignore the header, but deserialize the message body

    parameters body;

    result res = body.deserialize(
        body_buffers, body_buffer_sizes, num_of_body_buffers);
    assert(res == ok);

    // extract the content

    const char * value;
    std::size_t value_length;

    res = body.get_string("question", value, value_length);
    assert(res == ok);

    assert(std::strncmp(value, "ping", value_length) == 0);

    // prepare and send back the response

    parameters empty_header;
    parameters reply_body;

    res = reply_body.set_string("answer", "pong");
    assert(res == ok);

    res = server_agent->post(source, empty_header, reply_body);
    assert(res == ok);
}

void new_connection_function(
    void * /* hint */,
    const char * source,
    std::size_t /* index */, std::size_t /* sequence_number */)
{
    std::cout << "accepted incoming connection from "
        << source << std::endl;
}

void closed_connection(
    void * /* hint */,
    const char * name, result /* reason */)
{
    std::cout << "closed channel " << name << std::endl;
}

void run_server(const char * server_address)
{
    agent server_agent;

    // create the server agent and activate a listener on the given address

    result res = server_agent.init(
        &dispatch_function, &server_agent,
        &closed_connection, NULL);
    assert(res == ok);

    const char * resolved_address;
    res = server_agent.add_listener(
        server_address,
        &new_connection_function, NULL,
        &resolved_address);
    assert(res == ok);

    std::cout << "The server is listening on "
        << resolved_address << std::endl;

    // run the event loop
    // normally this loop would be executed by a separate thread,
    // but this server has nothing else to do, so it is possible
    // to process the I/O events here:

    std::cout << "waiting for messages..." << std::endl;

    const std::size_t time_out = 1000; // 1 second

    while (true)
    {
        res = server_agent.do_some_work(time_out);
        assert(res == ok || res == timed_out);
    }

    // never reaches here
}

int main(int argc, char * argv[])
{
    if (argc != 2)
    {
        std::cout << "expecting one parameter: server destination\n";
        return EXIT_FAILURE;
    }

    const char * server_address = argv[1];

    run_server(server_address);
}

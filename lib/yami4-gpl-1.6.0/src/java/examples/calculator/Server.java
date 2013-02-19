import com.inspirel.yami.Agent;
import com.inspirel.yami.IncomingMessage;
import com.inspirel.yami.IncomingMessageCallback;
import com.inspirel.yami.Parameters;

public class Server {
    private static class Calculator
        implements IncomingMessageCallback {

        @Override
        public void call(IncomingMessage im)
            throws Exception {

            // extract the parameters for calculations

            Parameters params = im.getParameters();

            int a = params.getInteger("a");
            int b = params.getInteger("b");

            // prepare the answer
            // with results of four calculations

            Parameters replyParams = new Parameters();

            replyParams.setInteger("sum", a + b);
            replyParams.setInteger("difference", a - b);
            replyParams.setInteger("product", a * b);

            // if the ratio cannot be computed,
            // it is not included in the response
            // the client will interpret that fact properly
            if (b != 0) {
                replyParams.setInteger("ratio", a / b);
            }

            im.reply(replyParams);

            System.out.println("got message with parameters " +
                a + " and " + b +
                ", response has been sent back");
        }
    }

    public static void main(String[] args) {
        if (args.length != 1) {
            System.out.println(
                "expecting one parameter: server destination");
            return;
        }

        String serverAddress = args[0];

        try {
            Agent serverAgent = new Agent();

            String resolvedAddress =
                serverAgent.addListener(serverAddress);

            System.out.println(
                "The server is listening on " +
                resolvedAddress);

            serverAgent.registerObject(
                "calculator", new Calculator());

            // block
            while (true) {
                Thread.sleep(10000);
            }
        } catch (Exception ex) {
            System.out.println(
                "error: " + ex.getMessage());
        }
    }
}

#include <yami4-cpp/yami.h>

#include <cstdlib>
#include <iostream>

#include "../common_utils/string_to_int.h"

void call(yami::incoming_message & im)
{
    const int index =
        im.get_parameters().get_integer("index");

    std::cout << "processing message " << index
        << " from " << im.get_source() << std::endl;
}

int main(int argc, char * argv[])
{
    if (argc != 2 && argc != 4)
    {
        std::cout << "need 1 or 3 parameters:\n"
            "   - server address\n"
            "   - incoming high water mark\n"
            "   - incoming low water mark\n"
            "If only server address is given,"
            " the limits will have default values\n";

        return EXIT_FAILURE;
    }

    const std::string server_address = argv[1];

    yami::parameters options;
    if (argc == 4)
    {
        int incoming_high_water_mark;
        int incoming_low_water_mark;

        if (examples::string_to_int(argv[2],
                incoming_high_water_mark) == false ||
            examples::string_to_int(argv[3],
                incoming_low_water_mark) == false)
        {
            std::cout << "invalid arguments\n";
            return EXIT_FAILURE;
        }

        options.set_integer("incoming_high_water_mark",
            incoming_high_water_mark);
        options.set_integer("incoming_low_water_mark",
            incoming_low_water_mark);
    }

    try
    {
        yami::agent server_agent(options);

        const std::string resolved_address =
            server_agent.add_listener(server_address);

        std::cout << "The server is listening on "
            << resolved_address << std::endl;

        server_agent.register_object("object", call);

        // block
        std::string dummy;
        std::cin >> dummy;
    }
    catch (const std::exception & e)
    {
        std::cout << "error: " << e.what() << std::endl;
    }
}

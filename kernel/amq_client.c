/*===========================================================================

    OpenAMQ client test program

    Copyright (c) 1991-2005 iMatix Corporation
 *===========================================================================*/

#include "asl.h"
#include "amq_client_connection.h"
#include "amq_client_session.h"
#include "version.h"

#define CLIENT_NAME "amqp_client/1.0"
#define NOWARRANTY \
"This is free software; see the source for copying conditions.  There is NO\n" \
"warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.\n" \
    "\n"
#define USAGE                                                               \
    "Syntax: program [options...]\n"                                        \
    "Options:\n"                                                            \
    "  -s server[:port] Name or address, port of server (localhost:7654)\n" \
    "  -n number        Number of messages to send/receive (1)\n"           \
    "  -b batch         Size of each batch (100)\n"                         \
    "  -x size          Size of each message (default = 1024)\n"            \
    "  -r repeat        Repeat test N times (1)\n"                          \
    "  -X exchange      Name of exchange to work with (EXCHANGE)\n"         \
    "  -R routing key   Routing key to publish to (QUEUE)\n"                \
    "  -Q queue         Queue to consume from (QUEUE)\n"                    \
    "  -t level         Set trace level (default = 0)\n"                    \
    "                   0=none, 1=low, 2=medium, 3=high\n"                  \
    "  -a               Use async consumers (default is browsing)\n"        \
    "  -8               Simulate 0.8 synchronous consumer\n"                \
    "  -m               Publish mandatory (default is no)\n"                \
    "  -I               Publish immediate (default is no)\n"                \
    "  -i               Show program statistics when ending (no)\n"         \
    "  -p               Use persistent messages (no)\n"                     \
    "  -d               Delayed mode; sleeps after receiving a message\n"   \
    "  -q               Quiet mode: no messages\n"                          \
    "  -v               Show version information\n"                         \
    "  -h               Show summary of command-line options\n"             \
    "\nThe order of arguments is not important. Switches and filenames\n"   \
    "are case sensitive. See documentation for detailed information.\n"     \
    "\n"

int
main (int argc, char *argv [])
{
    int
        argn;                           //  Argument number
    Bool
        args_ok = TRUE,                 //  Were the arguments okay?
        quiet_mode = FALSE,             //  -q means suppress messages
        delay_mode = FALSE,             //  -d means work slowly
        async_mode = FALSE,             //  -a means async consumers
        simul_mode = FALSE,             //  -8 means simulate 0.8 consumers
        mandatory = FALSE,              //  -m means publish mandatory
        immediate = FALSE,              //  -I means publish immediate
        showinfo = FALSE,               //  -i means show information
        persistent = FALSE;             //  -p means persistent messages
    char
        *opt_server,                    //  Host to connect to
        *opt_trace,                     //  0-3
        *opt_messages,                  //  Size of test set
        *opt_exchange,                  //  Exchange to work with
        *opt_routing,                   //  Routing key to publish to
        *opt_queue,                     //  Queue to consume from
        *opt_batch,                     //  Size of batches
        *opt_msgsize,                   //  Message size
        *opt_repeats,                   //  Test repetitions
        **argparm;                      //  Argument parameter to pick-up
    amq_client_connection_t
        *connection = NULL;             //  Current connection
    amq_client_session_t
        *session = NULL;                //  Current session
    amq_content_jms_t
        *content = NULL;                //  Message content
    dbyte
        ticket = 0;                     //  Access ticket
    byte
        *test_data = NULL;              //  Test message data
    int
        rc,                             //  Method return code
        count,
        messages,
        batch_left,
        batch_size,
        msgsize,
        repeats;
    Bool
        got_messages;                   //  Browsing indicator
    icl_shortstr_t
        message_id;                     //  Message identifier
    icl_longstr_t
        *auth_data;                     //  Authorisation data

    //  These are the arguments we may get on the command line
    opt_server   = "localhost";
    opt_trace    = "0";
    opt_messages = "1";
    opt_exchange = "EXCHANGE";
    opt_queue    = "QUEUE";
    opt_routing  =  NULL;               //  Same as queue by default
    opt_batch    = "100";
    opt_msgsize  = "1024";
    opt_repeats  = "1";

    //  Initialise system in order to use console.
    icl_system_initialise (argc, argv);

    argparm = NULL;                     //  Argument parameter to pick-up
    for (argn = 1; argn < argc; argn++) {
        //  If argparm is set, we have to collect an argument parameter
        if (argparm) {
            if (*argv [argn] != '-') {  //  Parameter can't start with '-'
                *argparm = argv [argn];
                argparm = NULL;
            }
            else {
                args_ok = FALSE;
                break;
            }
        }
        else
        if (*argv [argn] == '-') {
            switch (argv [argn][1]) {
                //  These switches take a parameter
                case 's':
                    argparm = &opt_server;
                    break;
                case 'n':
                    argparm = &opt_messages;
                    break;
                case 'b':
                    argparm = &opt_batch;
                    break;
                case 'X':
                    argparm = &opt_exchange;
                    break;
                case 'R':
                    argparm = &opt_routing;
                    break;
                case 'Q':
                    argparm = &opt_queue;
                    break;
                case 't':
                    argparm = &opt_trace;
                    break;
                case 'x':
                    argparm = &opt_msgsize;
                    break;
                case 'r':
                    argparm = &opt_repeats;
                    break;

                //  These switches have an immediate effect
                case 'p':
                    persistent = TRUE;
                    icl_console_print ("W: -p option is not yet implemented");
                    break;
                case 'a':
                    async_mode = TRUE;
                    break;
                case '8':
                    simul_mode = TRUE;
                    break;
                case 'm':
                    mandatory = TRUE;
                    break;
                case 'I':
                    immediate = TRUE;
                    break;
                case 'i':
                    showinfo = TRUE;
                    break;
                case 'q':
                    quiet_mode = TRUE;
                    break;
                case 'd':
                    delay_mode = TRUE;
                    break;
                case 'v':
                    printf (CLIENT_NAME " - revision " SVN_REVISION "\n\n");
                    printf (COPYRIGHT "\n");
                    printf (NOWARRANTY);
                    printf (BUILDMODEL "\n");
                    printf ("Compiled with: " CCOPTS "\n");
                    exit (EXIT_SUCCESS);
                case 'h':
                    printf (CLIENT_NAME "\n\n");
                    printf (COPYRIGHT "\n");
                    printf (NOWARRANTY);
                    printf (USAGE);
                    exit (EXIT_SUCCESS);

                //  Anything else is an error
                default:
                    args_ok = FALSE;
            }
        }
        else {
            args_ok = FALSE;
            break;
        }
    }
    //  If there was a missing parameter or an argument error, quit
    if (argparm) {
        icl_console_print ("E: argument missing - use '-h' option for help");
        exit (EXIT_FAILURE);
    }
    else
    if (!args_ok) {
        icl_console_print ("E: invalid arguments - use '-h' option for help");
        exit (EXIT_FAILURE);
    }
    messages   = atoi (opt_messages);
    batch_size = atoi (opt_batch);
    msgsize    = atoi (opt_msgsize);
    repeats    = atoi (opt_repeats);
    if (batch_size > messages)
        batch_size = messages;
    if (repeats < 1)
        repeats = -1;                   //  Loop forever
    if (opt_routing == NULL)
        opt_routing = opt_queue;

    //  Allocate a test message for publishing
    test_data = icl_mem_alloc (msgsize);
    memset (test_data, 0xAB, msgsize);

    if (atoi (opt_trace) > 2) {
        amq_client_connection_animate (TRUE);
        amq_client_session_animate (TRUE);
    }
    auth_data  = amq_client_connection_auth_plain ("guest", "guest");
    connection = amq_client_connection_new (
        opt_server, "/", auth_data, atoi (opt_trace), 30000);
    icl_longstr_destroy (&auth_data);

    if (connection)
        icl_console_print ("I: connected to %s/%s - %s - %s",
            connection->server_product,
            connection->server_version,
            connection->server_platform,
            connection->server_information);
    else {
        icl_console_print ("E: could not connect to server");
        goto finished;
    }
    session = amq_client_session_new (connection);
    if (!session) {
        icl_console_print ("E: could not open session to server");
        goto finished;
    }
    //  Declare exchange and queue
    if (amq_client_session_exchange_declare (session,
        ticket, opt_exchange, "direct", FALSE, FALSE, FALSE, FALSE))
        goto finished;
    if (amq_client_session_queue_declare (session,
        ticket, opt_queue, FALSE, FALSE, FALSE, FALSE))
        goto finished;

    //  Set-up a simple binding based on queue name
    rc = amq_client_session_queue_bind (
        session, ticket, opt_queue, opt_exchange, opt_queue, NULL);
    if (rc)
        goto finished;                  //  Quit if that failed

    if (async_mode) {
        amq_client_session_jms_consume (session,
            ticket,                     //  Access ticket granted by server
            opt_queue,                  //  Queue name
            0,                          //  Prefetch size
            0,                          //  Prefetch count
            FALSE,                      //  No local messages
            TRUE,                       //  Auto-acknowledge
            FALSE);                     //  Exclusive access to queue
        if (simul_mode)
            amq_client_session_flow (session, FALSE);
    }
    while (repeats) {
        //  Send messages to the test queue
        if (!quiet_mode)
            icl_console_print ("I: [%s] (%d) sending %d messages to server...",
                opt_routing, repeats, messages);
        batch_left = batch_size;
        for (count = 0; count < messages; count++) {
            content = amq_content_jms_new ();
            icl_shortstr_fmt (message_id, "ID%d", count);
            amq_content_jms_set_body       (content, test_data, msgsize, NULL);
            amq_content_jms_set_message_id (content, message_id);

            rc = amq_client_session_jms_publish (
                    session, content, ticket, opt_exchange,
                    opt_routing, mandatory, immediate);
            amq_content_jms_destroy (&content);
            if (rc) {
                icl_console_print ("E: [%s] could not send message to server - %s",
                    opt_queue, session->error_text);
                goto finished;
            }
            if (--batch_left == 0) {
                if (!quiet_mode)
                    icl_console_print ("I: [%s] commit batch %d...",
                        opt_queue, count / batch_size);
                batch_left = batch_size;
            }
        }
        //  Now read messages off the test queue
        if (!quiet_mode)
            icl_console_print ("I: [%s] (%d) - reading back messages...", opt_queue, repeats);
        if (async_mode && simul_mode)
            amq_client_session_flow (session, TRUE);

        count = 0;
        while (count < messages) {
            //  If we're browsing, do a synchronous get
            if (!async_mode)
                amq_client_session_jms_get (session, ticket, opt_queue, TRUE);

            //  Process whatever content has already arrived
            got_messages = FALSE;
            while ((content = amq_client_session_jms_arrived (session)) != NULL) {
                got_messages = TRUE;
                count++;
                if ((delay_mode || messages < 100) && !quiet_mode)
                    icl_console_print ("I: [%s] message number %s arrived",
                        opt_queue, content->message_id);
                if (count % batch_size == 0) {
                    if (!quiet_mode)
                        icl_console_print ("I: [%s] acknowledge batch %d...",
                            opt_queue, count / batch_size);
                }
                amq_content_jms_destroy (&content);
                if (delay_mode)
                    sleep (1);

                if (smt_signal_raised) {
                    icl_console_print ("I: SMT signal raised - ending test");
                    goto finished;
                }
            }
            //  Process bounced messages, if any
            while ((content = amq_client_session_jms_bounced (session)) != NULL) {
                got_messages = TRUE;
                count++;
                icl_console_print ("I: [%s] message number %s was bounced",
                    opt_queue, content->message_id);
                amq_content_jms_destroy (&content);
            }
            if (async_mode) {
                //  If we expect more, wait for something to happen
                if (count < messages && amq_client_session_wait (session, 0)) {
                    icl_console_print ("E: [%s] error receiving messages - ending test", opt_queue);
                    goto finished;      //  Quit if there was a problem
                }
            }
            else
            if (!got_messages)
                break;                  //  Browsing ended, no more data
        }
        if (!quiet_mode)
            icl_console_print ("I: [%s] received %d messages back from server", opt_queue, count);
        if (repeats > 0)
            repeats--;
    }
    if (async_mode)
        amq_client_session_jms_cancel (session, session->consumer_tag);

    finished:

    icl_mem_free (test_data);
    amq_client_session_destroy (&session);
    amq_client_connection_destroy (&connection);

    if (showinfo)
        icl_stats_dump ();

    icl_system_terminate ();
    return (0);
}


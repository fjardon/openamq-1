<?xml?>
<class
    name      = "amq_exchange_base"
    comment   = "Exchange abstract base class"
    version   = "1.0"
    copyright = "Copyright (c) 2004-2005 iMatix Corporation"
    script    = "icl_gen"
    abstract  = "1"
    >
<doc>
This is an abstract base class for all exchange implementations.
</doc>

<inherit class = "icl_object">
    <option name = "alloc" value = "cache" />
</inherit>

<public name = "include">
#include "amq_server_classes.h"
</public>

<context>
    amq_exchange_t
        *exchange;                      //  Parent exchange
</context>

<method name = "new">
    <argument name = "exchange" type = "amq_exchange_t *">Parent exchange</argument>
    //
    self->exchange = exchange;
</method>

<method name = "compile" return = "rc">
    <doc>
    Compiles the binding for the exchange, returns 1 if the binding was
    invalid.
    </doc>
    <argument name = "self_v"  type = "void *">The exchange cast as a void *</argument>
    <argument name = "binding" type = "amq_binding_t *">Binding to compile</argument>
    <argument name = "channel" type = "amq_server_channel_t *">Channel for errors</argument>
    <declare name = "rc" type = "int" default = "0">Return code</declare>
    <local>
    $(selftype)
        *self = self_v;
    </local>
</method>

<method name = "publish" return = "rc">
    <doc>
    Routes one message through the exchange.
    </doc>
    <argument name = "self_v"    type = "void *">The exchange cast as a void *</argument>
    <argument name = "channel"   type = "amq_server_channel_t *">Channel for reply</argument>
    <argument name = "class id"  type = "int">The content class</argument>
    <argument name = "content"   type = "void *">The message content</argument>
    <argument name = "mandatory" type = "Bool">Warn if unroutable</argument>
    <argument name = "immediate" type = "Bool">Warn if no consumers</argument>
    <declare name = "rc" type = "int" default = "0">Return code</declare>
    <local>
    $(selftype)
        *self = self_v;
    char
        *destination = "";
    Bool
        delivered = FALSE;              //  Set to TRUE if message processed
    </local>
    //
    <header>
    if (class_id == AMQ_SERVER_JMS)
        destination = ((amq_content_jms_t *) content)->destination;
    else
    if (class_id == AMQ_SERVER_BASIC)
        destination = ((amq_content_basic_t *) content)->destination;
    </header>
    <footer>
    if (!delivered && mandatory) {
        if (class_id == AMQ_SERVER_JMS) {
            amq_server_agent_jms_bounce (
                channel->connection->thread,
                (dbyte) channel->key,
                content,
                ASL_NOT_DELIVERED,
                "No bindings for this destination",
                ((amq_content_jms_t *) content)->exchange,
                ((amq_content_jms_t *) content)->destination);
        }
        else
        if (class_id == AMQ_SERVER_BASIC) {
            amq_server_agent_basic_bounce (
                channel->connection->thread,
                (dbyte) channel->key,
                content,
                ASL_NOT_DELIVERED,
                "No bindings for this destination",
                ((amq_content_basic_t *) content)->exchange,
                ((amq_content_basic_t *) content)->destination);
        }
    }
    </footer>
</method>

<method name = "selftest" />

</class>
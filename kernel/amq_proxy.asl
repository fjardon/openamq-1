<?xml version="1.0"?>
<protocol
    comment  = "OpenAMQ server protocol methods"
    script   = "asl_gen"
    chassis  = "client"
    basename = "amq_proxy"
    >
<!--
    Defines the proxy client protocol methods and how they are
    processed.
    -->
    
<inherit name = "amq_cluster" />
<inherit name = "amq" />

<option name = "product_name"   value = "OpenAMQ Kernel Proxy" />
<option name = "import_classes" value = "amq_server_classes" />

<class name = "connection">
  <action name = "start">
    <local>
    asl_field_list_t
        *fields;                        //  Decoded responses
    icl_shortstr_t
        name;
    </local>
    //
    fields = asl_field_list_new (method->server_properties);
    assert (fields);
    asl_field_list_cpy (fields, name, "name");
    asl_field_list_unlink (&fields);
    assert (*name);
    assert (amq_cluster);

    //  Tell the cluster that the peer we're talking to is now alive
    amq_cluster_peer_ready (amq_cluster, session, name);
  </action>
</class>

<class name = "basic">
  <action name = "deliver">
    amq_consumer_t
        *consumer;                      //  Consumer to send message to
    amq_content_$(class.name)_t
        *content;                       //  Current content

    consumer = amq_consumer_cluster_search (method->consumer_tag);
    if (consumer) {
        content = (amq_content_$(class.name)_t *) self->content;
        amq_server_agent_$(class.name)_deliver (
            consumer->channel->connection->thread,
            consumer->channel->number,
            content,
            consumer->tag,
            0,                          //  Delivery tag
            FALSE,                      //  Redelivered
            method->exchange,
            method->routing_key);
        amq_consumer_unlink (&consumer);
    }
  </action>

  <action name = "get-ok">
    amq_content_$(class.name)_t
        *content;                       //  Current content
    amq_server_channel_t
        *channel;                       //  Channel to send message on to

    //  We use content's cluster_id to know where to forward content
    content = (amq_content_$(class.name)_t *) self->content;
    channel = amq_server_channel_cluster_search (content->cluster_id);
    if (channel) {
        amq_server_agent_$(class.name)_get_ok (
            channel->connection->thread,
            channel->number,
            content,
            method->delivery_tag,
            method->redelivered,
            method->exchange,
            method->routing_key,
            method->message_count);
        amq_server_channel_unlink (&channel);
        ipr_meter_count (amq_broker->xmeter);
    }
    else
        icl_console_print ("E: no channel for proxied message, discarding");
  </action>

  <action name = "get-empty">
    amq_server_channel_t
        *channel;                       //  Channel to send message to

    //  The method actually has the cluster id in it, still
    channel = amq_server_channel_cluster_search (method->cluster_id);
    if (channel) {
        amq_server_agent_$(class.name)_get_empty (
            channel->connection->thread,
            channel->number,
            NULL);                      //  Cluster_id is null
        amq_server_channel_unlink (&channel);
    }
  </action>
</class>

<class name = "file">
<!--
    to handle file deliveries, which are staged, we should probably make a
    channel method that accepts the delivery and handles it according to
    the class type.

    question: where do we put the file-related delivery mechanism? Maybe
    amq_consumer_file.icl?
  -->
</class>

</protocol>

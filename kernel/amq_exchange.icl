<?xml?>
<class
    name      = "amq_exchange"
    comment   = "Polymorphic exchange class"
    version   = "1.0"
    script    = "smt_object_gen"
    target    = "smt"
    >
<doc>
This class implements the server exchange, an asynchronous
object that acts as a envelope for the separate exchange managers
for each type of exchange. This is a lock-free asynchronous class.
</doc>

<option name = "links" value = "1"/>

<inherit class = "smt_object" />
<inherit class = "icl_hash_item">
    <option name = "hash_type" value = "str" />
    <option name = "hash_size" value = "65535" />
</inherit>
<inherit class = "icl_list_item">
    <option name = "prefix" value = "by_vhost" />
</inherit>
<inherit class = "amq_console_object" />
<inherit class = "smt_object_tracker" />

<!-- Console definitions for this object -->
<data name = "cml">
    <class name = "exchange" parent = "vhost" label = "Exchange">
        <field name = "name">
          <get>icl_shortstr_cpy (field_value, self->name);</get>
        </field>
        <field name = "type">
          <get>icl_shortstr_cpy (field_value, amq_exchange_type_name (self->type));</get>
        </field>
        <field name = "durable" label = "Durable exchange?" type = "bool">
          <get>icl_shortstr_fmt (field_value, "%d", self->durable);</get>
        </field>
        <field name = "auto_delete" label = "Auto-deleted?" type = "bool">
          <get>icl_shortstr_fmt (field_value, "%d", self->auto_delete);</get>
        </field>
        <field name = "bindings" label = "Number of bindings" type = "int">
          <rule name = "show on summary" />
          <get>icl_shortstr_fmt (field_value, "%d", amq_binding_list_count (self->binding_list));</get>
        </field>
        <field name = "traffic_in" type = "int" label = "Inbound traffic, MB">
          <rule name = "show on summary" />
          <get>icl_shortstr_fmt (field_value, "%d", (int) (self->traffic_in / (1024 * 1024)));</get>
        </field>
        <field name = "traffic_out" type = "int" label = "Outbound traffic, MB">
          <rule name = "show on summary" />
          <get>icl_shortstr_fmt (field_value, "%d", (int) (self->traffic_out / (1024 * 1024)));</get>
        </field>
        <field name = "contents_in" type = "int" label = "Total messages received">
          <get>icl_shortstr_fmt (field_value, "%d", self->contents_in);</get>
        </field>
        <field name = "contents_out" type = "int" label = "Total messages sent">
          <get>icl_shortstr_fmt (field_value, "%d", self->contents_out);</get>
        </field>
    </class>
</data>

<import class = "amq_server_classes" />

<context>
    amq_vhost_t
        *vhost;                         //  Parent vhost
    int
        type;                           //  Exchange type
    icl_shortstr_t
        name;                           //  Exchange name
    Bool
        durable,                        //  Is exchange durable?
        auto_delete,                    //  Auto-delete unused exchange?
        internal;                       //  Internal exchange?
    void
        *object;                        //  Exchange implementation
    amq_binding_list_t
        *binding_list;                  //  Bindings as a list
    ipr_hash_table_t
        *binding_hash;                  //  Bindings hashed by routing_key
    ipr_index_t
        *binding_index;                 //  Gives us binding indices

    //  Exchange access functions
    int
        (*publish) (
            void                 *self,
            amq_server_channel_t *channel,
            amq_server_method_t  *method,
            Bool                  from_cluster);
    int
        (*compile) (
            void                 *self,
            amq_binding_t        *binding,
            amq_server_channel_t *channel);
    int
        (*unbind) (
            void                 *self,
            amq_binding_t        *binding);

    //  Statistics
    int64_t
        traffic_in,                     //  Traffic in, in octets
        traffic_out,                    //  Traffic out, in octets
        contents_in,                    //  Contents in, in octets
        contents_out;                   //  Contents out, in octets
</context>

<public name = "header">
//  Exchange types we implement

#define AMQ_EXCHANGE_SYSTEM         1
#define AMQ_EXCHANGE_FANOUT         2
#define AMQ_EXCHANGE_DIRECT         3
#define AMQ_EXCHANGE_TOPIC          4
#define AMQ_EXCHANGE_HEADERS        5
</public>

<method name = "new">
    <argument name = "vhost" type = "amq_vhost_t *">Parent vhost</argument>
    <argument name = "type" type = "int">Exchange type</argument>
    <argument name = "name" type = "char *">Exchange name</argument>
    <argument name = "durable" type = "Bool">Is exchange durable?</argument>
    <argument name = "auto delete" type = "Bool">Auto-delete unused exchange?</argument>
    <argument name = "internal" type = "Bool">Internal exchange?</argument>
    <dismiss argument = "key" value = "name">Key is exchange name</dismiss>
    //
    self->vhost         = vhost;
    self->type          = type;
    self->durable       = durable;
    self->auto_delete   = auto_delete;
    self->internal      = internal;
    self->binding_list  = amq_binding_list_new ();
    self->binding_hash  = ipr_hash_table_new ();
    self->binding_index = ipr_index_new ();
    icl_shortstr_cpy (self->name, name);

    if (self->type == AMQ_EXCHANGE_SYSTEM) {
        self->object  = amq_exchange_system_new (self);
        self->publish = amq_exchange_system_publish;
        self->compile = amq_exchange_system_compile;
        self->unbind  = amq_exchange_system_unbind;
    }
    else
    if (self->type == AMQ_EXCHANGE_FANOUT) {
        self->object  = amq_exchange_fanout_new (self);
        self->publish = amq_exchange_fanout_publish;
        self->compile = amq_exchange_fanout_compile;
        self->unbind  = amq_exchange_fanout_unbind;
    }
    else
    if (self->type == AMQ_EXCHANGE_DIRECT) {
        self->object  = amq_exchange_direct_new (self);
        self->publish = amq_exchange_direct_publish;
        self->compile = amq_exchange_direct_compile;
        self->unbind  = amq_exchange_direct_unbind;
    }
    else
    if (self->type == AMQ_EXCHANGE_TOPIC) {
        self->object  = amq_exchange_topic_new (self);
        self->publish = amq_exchange_topic_publish;
        self->compile = amq_exchange_topic_compile;
        self->unbind  = amq_exchange_topic_unbind;
    }
    else
    if (self->type == AMQ_EXCHANGE_HEADERS) {
        self->object  = amq_exchange_headers_new (self);
        self->publish = amq_exchange_headers_publish;
        self->compile = amq_exchange_headers_compile;
        self->unbind  = amq_exchange_headers_unbind;
    }
    else
        asl_log_print (amq_broker->alert_log,
            "E: invalid type '%d' in exchange_new", self->type);

    amq_exchange_by_vhost_queue (self->vhost->exchange_list, self);
</method>

<method name = "destroy">
    <action>
    ipr_hash_table_destroy (&self->binding_hash);
    amq_binding_list_destroy (&self->binding_list);
    ipr_index_destroy (&self->binding_index);
    if (self->type == AMQ_EXCHANGE_SYSTEM)
        amq_exchange_system_destroy ((amq_exchange_system_t **) &self->object);
    else
    if (self->type == AMQ_EXCHANGE_FANOUT)
        amq_exchange_fanout_destroy ((amq_exchange_fanout_t **) &self->object);
    else
    if (self->type == AMQ_EXCHANGE_DIRECT)
        amq_exchange_direct_destroy ((amq_exchange_direct_t **) &self->object);
    else
    if (self->type == AMQ_EXCHANGE_TOPIC)
        amq_exchange_topic_destroy ((amq_exchange_topic_t **) &self->object);
    else
    if (self->type == AMQ_EXCHANGE_HEADERS)
        amq_exchange_headers_destroy ((amq_exchange_headers_t **) &self->object);
    </action>
</method>

<method name = "type lookup" return = "rc">
    <doc>
    Translates an exchange type name into an internal type number.  If
    the type name is not valid, returns zero, else returns one of the
    type numbers supported by this implementation.
    </doc>
    <argument name = "type name" type = "char *">Type name to lookup</argument>
    <declare name = "rc" type = "int">Type number</declare>
    //
    if (streq (type_name, "system"))
        rc = AMQ_EXCHANGE_SYSTEM;
    else
    if (streq (type_name, "fanout"))
        rc = AMQ_EXCHANGE_FANOUT;
    else
    if (streq (type_name, "direct"))
        rc = AMQ_EXCHANGE_DIRECT;
    else
    if (streq (type_name, "topic"))
        rc = AMQ_EXCHANGE_TOPIC;
    else
    if (streq (type_name, "headers"))
        rc = AMQ_EXCHANGE_HEADERS;
    else
        rc = 0;
</method>

<method name = "type name" return = "name">
    <doc>
    Translates an exchange type index into an external name.
    </doc>
    <argument name = "type" type = "int">Type index to translate</argument>
    <declare name = "name" type = "char *">Type name</declare>
    //
    if (type == AMQ_EXCHANGE_SYSTEM)
        name = "system";
    else
    if (type == AMQ_EXCHANGE_FANOUT)
        name = "fanout";
    else
    if (type == AMQ_EXCHANGE_DIRECT)
        name = "direct";
    else
    if (type == AMQ_EXCHANGE_TOPIC)
        name = "topic";
    else
    if (type == AMQ_EXCHANGE_HEADERS)
        name = "headers";
    else
        name = "(unknown)";
</method>

<method name = "bind queue" template = "async function" async = "1">
    <doc>
    Bind a queue to the exchange.  The logic is the same for all exchange
    types - we compare all existing bindings and if we find one that
    matches our arguments (has identical arguments) we attach the queue
    to the binding.  Otherwise we create a new binding and compile it
    into the exchange, this operation being exchange type-specific.
    </doc>
    <argument name = "channel"     type = "amq_server_channel_t *">Channel for reply</argument>
    <argument name = "queue"       type = "amq_queue_t *">The queue to bind</argument>
    <argument name = "routing key" type = "char *">Bind to routing key</argument>
    <argument name = "arguments"   type = "icl_longstr_t *">Bind arguments</argument>
    //
    <possess>
    channel = amq_server_channel_link (channel);
    queue = amq_queue_link (queue);
    arguments = icl_longstr_dup (arguments);
    routing_key = icl_mem_strdup (routing_key);
    </possess>
    <release>
    amq_server_channel_unlink (&channel);
    amq_queue_unlink (&queue);
    icl_longstr_destroy (&arguments);
    icl_mem_free (routing_key);
    </release>
    //
    <action>
    if (amq_server_config_debug_route (amq_server_config))
        asl_log_print (amq_broker->debug_log,
            "X: bind     %s: queue=%s", self->name, queue->name);

    s_bind_object (self, channel, queue, NULL, routing_key, arguments);
    </action>
</method>

<method name = "bind peer" template = "async function" async = "1">
    <doc>
    Bind a cluster peer to the exchange.  Works identically as for
    bind queue.
    </doc>
    <argument name = "peer"        type = "amq_peer_t *">The peer to bind</argument>
    <argument name = "routing key" type = "char *">Bind to routing key</argument>
    <argument name = "arguments"   type = "icl_longstr_t *">Bind arguments</argument>
    //
    <possess>
    peer = amq_peer_link (peer);
    arguments = icl_longstr_dup (arguments);
    routing_key = icl_mem_strdup (routing_key);
    </possess>
    <release>
    amq_peer_unlink (&peer);
    icl_longstr_destroy (&arguments);
    icl_mem_free (routing_key);
    </release>
    //
    <action>
    if (amq_server_config_debug_route (amq_server_config))
        asl_log_print (amq_broker->debug_log,
            "X: bind     %s: peer=%s", self->name, peer->name);

    s_bind_object (self, NULL, NULL, peer, routing_key, arguments);
    </action>
</method>

<method name = "publish" template = "async function" async = "1">
    <doc>
    Publishes the message to the exchange.  The actual routing mechanism
    is defined in the exchange implementations.
    </doc>
    <argument name = "channel" type = "amq_server_channel_t *">Channel for reply</argument>
    <argument name = "method"  type = "amq_server_method_t *">Publish method</argument>
    <argument name = "from_cluster" type = "Bool">Intra-cluster publish?</argument>
    //
    <possess>
    channel = amq_server_channel_link (channel);
    method = amq_server_method_link (method);
    </possess>
    <release>
    amq_server_channel_unlink (&channel);
    amq_server_method_unlink (&method);
    </release>
    //
    <action>
    int
        delivered;                      //  Number of message deliveries
    int64_t
        content_size;

    delivered = self->publish (self->object, channel, method, from_cluster);
    content_size = ((amq_content_basic_t *) method->content)->body_size;

    //  Track exchange statistics
    self->contents_in  += 1;
    self->contents_out += delivered;
    self->traffic_in   += content_size;
    self->traffic_out  += (delivered * content_size);
    </action>
</method>

<method name = "unbind queue" template = "async function" async = "1">
    <doc>
    Unbind a queue from the exchange.
    </doc>
    <argument name = "queue" type = "amq_queue_t *">The queue to unbind</argument>
    //
    <possess>
    queue = amq_queue_link (queue);
    </possess>
    <release>
    amq_queue_unlink (&queue);
    </release>
    //
    <action>
    amq_binding_t
        *binding,
        *target;

    binding = amq_binding_list_first (self->binding_list);
    while (binding) {
        if (amq_binding_unbind_queue (binding, queue)) {
            //  Allow the exchange implementation the chance to cleanup the
            //  binding, but be careful to get the next binding first...
            target = binding;
            binding = amq_binding_list_next (&binding);
            self->unbind (self->object, target);
        }
        else
            binding = amq_binding_list_next (&binding);
    }
    </action>
</method>

<method name = "unbind peer" template = "async function" async = "1">
    <doc>
    Unbind a cluster peer from the exchange.
    </doc>
    <argument name = "peer" type = "amq_peer_t *">The peer to unbind</argument>
    //
    <possess>
    peer = amq_peer_link (peer);
    </possess>
    <release>
    amq_peer_unlink (&peer);
    </release>
    //
    <action>
    amq_binding_t
        *binding,
        *target;

    binding = amq_binding_list_first (self->binding_list);
    while (binding) {
        if (amq_binding_unbind_peer (binding, peer)) {
            //  Allow the exchange implementation the chance to cleanup the
            //  binding, but be careful to get the next binding first...
            target = binding;
            binding = amq_binding_list_next (&binding);
            self->unbind (self->object, target);
        }
        else
            binding = amq_binding_list_next (&binding);
    }
    </action>
</method>

<private name = "async header">
//  Bind an object
static void
    s_bind_object (
        amq_exchange_t *self,
        amq_server_channel_t *channel,
        amq_queue_t    *queue,
        amq_peer_t     *peer,
        char           *routing_key,
        icl_longstr_t  *arguments);
</private>

<private name = "async footer">
/*
    Bind a queue or peer to the exchange.
    The logic is the same for all exchange types - we compare all
    existing bindings and if we find one that matches our arguments
    (has identical arguments) we attach the queue to the binding.
    Otherwise we create a new binding and compile it into the exchange,
    this operation being exchange type-specific.
 */
static void
s_bind_object (
    amq_exchange_t *self,
    amq_server_channel_t *channel,
    amq_queue_t     *queue,
    amq_peer_t      *peer,
    char            *routing_key,
    icl_longstr_t   *arguments)
{
    amq_binding_t
        *binding = NULL;                //  New binding created
    ipr_hash_t
        *hash;                          //  Entry into hash table

    //  Treat empty arguments as null to simplify comparisons
    if (arguments && arguments->cur_size == 0)
        arguments = NULL;

    //  We need to know if this is a new binding or not
    //  First, we'll check on the routing key
    hash = ipr_hash_table_search (self->binding_hash, routing_key);
    if (hash) {
        //  We found the same routing key, now we need to check
        //  all bindings to check for an exact match
        binding = amq_binding_list_first (self->binding_list);
        while (binding) {
            if (streq (binding->routing_key, routing_key)
            && icl_longstr_eq (binding->arguments, arguments))
                break;
            binding = amq_binding_list_next (&binding);
        }
    }
    if (!binding) {
        //  If no binding matched, create a new one and compile it
        binding = amq_binding_new (self, routing_key, arguments);
        assert (binding);
        if (!hash)                      //  Hash routing key if needed
            hash = ipr_hash_new (self->binding_hash, routing_key, binding);

        //  Compile binding and put all 'wildcard' bindings at the front
        //  of the list. The meaning of this flag depends on the exchange.
        if (self->compile (self->object, binding, channel) == 0) {
            if (binding->is_wildcard)
                amq_binding_list_push (self->binding_list, binding);
            else
                amq_binding_list_queue (self->binding_list, binding);
        }
    }
    if (queue)
        amq_binding_bind_queue (binding, queue);
    else
    if (peer)
        amq_binding_bind_peer (binding, peer);

    amq_binding_unlink (&binding);
    ipr_hash_unlink (&hash);
}
</private>

<method name = "selftest" />

</class>

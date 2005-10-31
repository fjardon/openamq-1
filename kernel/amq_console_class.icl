<?xml?>
<class
    name      = "amq_console_class"
    comment   = "AMQ Console class descriptor"
    version   = "1.0"
    copyright = "Copyright (c) 2004-2005 iMatix Corporation"
    script    = "icl_gen"
    >
<doc>
This class defines a class descriptor.
</doc>

<inherit class = "icl_object">
    <option name = "alloc" value = "cache" />
</inherit>

<public name = "include">
#include "amq_server_classes.h"
</public>

<context>
    char
        *name;                          //  Name of class
    int (*inspect) (
        void
            *self,                      //  Object reference
        amq_content_basic_t
            *request,                   //  Original request
        Bool
            detail                      //  Want details of children?
    );
    //  modify method
    //  method method
</context>

<method name = "selftest" />

</class>

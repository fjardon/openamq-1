/*---------------------------------------------------------------------------
 *  amq_stdc_error.h - AMQ Client API error codes
 *
 *  Copyright (c) 2004-2005 JPMorgan
 *  Copyright (c) 1991-2005 iMatix Corporation
 *---------------------------------------------------------------------------*/

#ifndef AMQ_STDC_ERROR_H_INCLUDED
#define AMQ_STDC_ERROR_H_INCLUDED

/*  error value received when object (connection, channel, handle) was  */
/*  closed by server or another thread during or prior to function      */
/*  execution                                                           */
#define AMQ_OBJECT_CLOSED (APR_OS_START_USERERR +2)

#endif
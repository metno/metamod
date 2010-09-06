#!/bin/sh
createuser --adduser --createdb [==PG_ADMIN_USER==] 
createuser --no-adduser --no-createdb [==PG_WEB_USER==]

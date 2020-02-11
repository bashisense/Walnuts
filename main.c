
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/types.h>
#include <sys/stat.h>

#include <sys/stat.h>
#include <sys/socket.h>
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>

#include <signal.h>

#include <event2/event.h>
#include <event2/http.h>
#include <event2/listener.h>
#include <event2/buffer.h>
#include <event2/util.h>
#include <event2/keyvalq_struct.h>

# include <arpa/inet.h>

#include <lua.h>                                /* Always include this when calling Lua */
#include <lauxlib.h>                            /* Always include this when calling Lua */
#include <lualib.h>                             /* Prototype for luaL_openlibs(), */
                                                /*   always include this when calling Lua */

#include <stdlib.h>                             /* For function exit() */
#include <stdio.h>                              /* For input/output */


void bail(lua_State *L, char *msg){
	fprintf(stderr, "\nFATAL ERROR:\n  %s: %s\n\n",
		msg, lua_tostring(L, -1));
	exit(1);
}

static void dump_cb(struct evhttp_request *req, void *arg)
{
    lua_State *L = (lua_State *)arg;
	evhttp_send_reply(req, 200, "OK", NULL);
}


static void default_cb(struct evhttp_request *req, void *arg)
{
	const char *uri = evhttp_request_get_uri(req);
    lua_State *L = (lua_State *)arg;
    struct evbuffer *evbuf;
    size_t size;
    char *cbuf;

    evbuf = evhttp_request_get_input_buffer(req);
    size  = evbuffer_get_length(evbuf);
    cbuf = malloc(size + 1);
    if(cbuf == NULL){
        printf("evhttp_get_reqjson => alloc buffer for json parse fail!\n");
        return ;
    }

    evbuffer_copyout(evbuf, cbuf, size);
    cbuf[size] = '\0';

	printf("Got a GET request for <%s>\n",  uri);
	printf("request body: %s\n", cbuf);

    lua_getglobal(L, "handler");
    lua_pushstring(L, cbuf); 
    if (lua_pcall(L, 1, 1, 0))
	bail(L, "lua_pcall() failed"); 

    printf("Back in C again\n");
    int mynumber = lua_tonumber(L, -1);
    printf("Returned number=%d\n", mynumber);

	free(cbuf);

	evhttp_send_reply(req, 200, "OK", NULL);
}

int main()
{
	struct event_base *base = NULL;
	struct evhttp *http = NULL;

    lua_State *L;

	printf("starting ...\n");
    L = luaL_newstate();                        /* Create Lua state variable */
	printf("init new state ...\n");

    luaL_openlibs(L);                           /* Load Lua libraries */

	printf("load handler.lua \n");
    if (luaL_loadfile(L, "/Users/konghan/Workspace/lua-test/handler.lua"))
        bail(L, "luaL_loadfile() failed");      /* Error out if file can't be read */


    if (lua_pcall(L, 0, 0, 0))                  /* PRIMING RUN. FORGET THIS AND YOU'RE TOAST */
        bail(L, "lua_pcall() failed");          /* Error out if Lua file has an error */

    lua_getglobal(L, "tellme");                 /* Tell it to run callfuncscript.lua->tellme() */
    if (lua_pcall(L, 0, 0, 0))                  /* Run the function */
        bail(L, "lua_pcall() failed");          /* Error out if Lua file has an error */

	printf("init lua ok\n");

	base = event_base_new();
	if (!base) {
		fprintf(stderr, "Couldn't create an event_base: exiting\n");
		return -1;
	}

	/* Create a new evhttp object to handle requests. */
	http = evhttp_new(base);
	if (!http) {
		fprintf(stderr, "couldn't create evhttp. Exiting.\n");
		return -1;
	}

	evhttp_set_cb(http, "/dump", dump_cb, L);

	evhttp_set_gencb(http, default_cb, L);

    evhttp_bind_socket(http, "0.0.0.0", 8080);

	event_base_dispatch(base);

    lua_close(L);                               /* Clean up, free the Lua state var */

	return 0;
}

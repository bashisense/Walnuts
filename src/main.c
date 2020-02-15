
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

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <stdlib.h>
#include <stdio.h>

static const char   *walnuts_luascript = "../lua/walnuts.lua";
static lua_State    *walnuts_state;
static int walnuts_errhandler = 0;

void fail(char *msg){
	fprintf(stderr, "FATAL ERROR: %s\n", msg);
	exit(1);
}


static int exec_lua_routine(lua_State *ls, const char *routine, char *param){
    int ret;

    // fprintf(stderr, "\nexec_lua_routine -> call lua routine: %s - %s\n", routine, param);

    lua_getglobal(ls, routine);
    lua_pushstring(ls, param); 

    ret = lua_pcall(ls, 1, 1, walnuts_errhandler);
    if(ret != 0){
        fprintf(stderr, "%s -> lua_pcall fail:%d, %s\n", routine, ret, lua_tostring(ls, -1));
        lua_pop(ls, 1);
        return -1;
    }

    ret = lua_tonumber(ls, -1);

    lua_pop(ls, 1);

    // fprintf(stderr, "exec_lua_routine -> return from lua %d\n", ret);

    return ret;
}


static void sqlite_cb(struct evhttp_request *req, void *arg)
{
    lua_State *ls = (lua_State *)arg;
    struct evbuffer *evbuf;
    size_t size;
    char *cbuf;

    evbuf = evhttp_request_get_input_buffer(req);
    size  = evbuffer_get_length(evbuf);
    cbuf = malloc(size + 1);
    if(cbuf == NULL){
        fprintf(stderr, "sqlite_cb => alloc buffer for json parse fail!\n");
        return ;
    }

    evbuffer_copyout(evbuf, cbuf, size);
    cbuf[size] = '\0';

    exec_lua_routine(ls, "Walnuts_test_sqlite", cbuf);

	free(cbuf);


	evhttp_send_reply(req, 200, "OK", NULL);
}

static void cjson_cb(struct evhttp_request *req, void *arg)
{
    lua_State *ls = (lua_State *)arg;
    struct evbuffer *evbuf;
    size_t size;
    char *cbuf;

    evbuf = evhttp_request_get_input_buffer(req);
    size  = evbuffer_get_length(evbuf);
    cbuf = malloc(size + 1);
    if(cbuf == NULL){
        fprintf(stderr, "sqlite_cb => alloc buffer for json parse fail!\n");
        return ;
    }

    evbuffer_copyout(evbuf, cbuf, size);
    cbuf[size] = '\0';

    exec_lua_routine(ls, "Walnuts_test_cjson", cbuf);

	free(cbuf);

	evhttp_send_reply(req, 200, "OK", NULL);
}


static void default_cb(struct evhttp_request *req, void *arg)
{
    lua_State *ls = (lua_State *)arg;
    struct evbuffer *evbuf;
    size_t size;
    char *body;
    int ret;
    int stack_top;

    const char *path = evhttp_uri_get_path(evhttp_request_get_evhttp_uri(req));
    int cmd    = evhttp_request_get_command(req);

    evbuf = evhttp_request_get_input_buffer(req);
    size  = evbuffer_get_length(evbuf);
    body = malloc(size + 1);
    if(body == NULL){
        fprintf(stderr, "sqlite_cb => alloc buffer for json parse fail!\n");
	    evhttp_send_reply(req, 404, "OK", NULL);
        return ;
    }

    evbuffer_copyout(evbuf, body, size);
    body[size] = '\0';

    printf("before stack : %d\n", lua_gettop(ls));

    stack_top = lua_gettop(ls);

    lua_getglobal(ls, "WnLocalDispatch");
    lua_pushlightuserdata(ls, req);
    lua_pushstring(ls, body);

    ret = lua_pcall(ls, 2, 1, walnuts_errhandler);
    if(ret != 0){
        lua_settop(ls, stack_top);
        fprintf(stderr, "default_cb -> lua_pcall fail:%d\n", ret);
	    evhttp_send_reply(req, 404, "OK", NULL);
	    free(body);
        return ;
    }

    ret = lua_tonumber(ls, -1);
    lua_settop(ls, stack_top);
    printf("after stack : %d\n", lua_gettop(ls));
	free(body);
}

static int Walnuts_init_luastate(){

	fprintf(stderr, "Walnuts_init_luastate -> starting ...\n");

    walnuts_state = luaL_newstate();
    if(walnuts_state == NULL){
        fail("luaL_newstate return NULL");
    }

    luaL_openlibs(walnuts_state);

    if (luaL_loadfile(walnuts_state, walnuts_luascript))
        fail("luaL_loadfile() failed");

    if (lua_pcall(walnuts_state, 0, 0, 0)) 
        fail("call lua global code failed");

    lua_getglobal(walnuts_state, "WnErrorHandler");
    walnuts_errhandler = lua_gettop(walnuts_state);

    return exec_lua_routine(walnuts_state, "WnInit", "init");
}

static int Walnuts_fini_luastate(){
    int ret;

    ret = exec_lua_routine(walnuts_state, "WnFini", "fini");

    lua_close(walnuts_state);

    return ret;
}

const char *GetPath(void *request){
    struct evhttp_request *req = (struct evhttp_request *)request;

    return evhttp_uri_get_path(evhttp_request_get_evhttp_uri(req));
}

int GetMethod(void *request){
    struct evhttp_request *req = (struct evhttp_request *)request;
    
    return evhttp_request_get_command(req);
}

void ReplyToClient(void *request, const char *rspjson){
    struct evhttp_request *req = (struct evhttp_request *)request;
    struct evbuffer *evbuf;
    int len;
    int size;

    if(rspjson != NULL){
        fprintf(stderr, "ReplyToClient -> %s\n", rspjson);
    }else{
        fprintf(stderr, "ReplyToClient -> NULL\n");
	    evhttp_send_reply(req, 200, "OK", NULL);
        return ;
    }

    evbuf = evbuffer_new();
    len  = strlen(rspjson);
    size += 4 - (len % 4);
    evbuffer_expand(evbuf, size);
    evbuffer_add(evbuf, rspjson, len);

	evhttp_send_reply(req, 200, "OK", evbuf);

    evbuffer_free(evbuf);
}

int main()
{
	struct event_base *base = NULL;
	struct evhttp *http = NULL;

    Walnuts_init_luastate();

	base = event_base_new();
	if (!base) {
		fprintf(stderr, "Couldn't create an event_base: exiting\n");
		return -1;
	}

	http = evhttp_new(base);
	if (!http) {
		fprintf(stderr, "couldn't create evhttp. Exiting.\n");
		return -1;
	}

	evhttp_set_cb(http, "/sqlite",  sqlite_cb,  walnuts_state);
	evhttp_set_cb(http, "/cjson",   cjson_cb,   walnuts_state);

	evhttp_set_gencb(http, default_cb, walnuts_state);

    evhttp_bind_socket(http, "0.0.0.0", 8080);

	event_base_dispatch(base);

	return 0;
}

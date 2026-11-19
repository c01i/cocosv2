#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    lua_State *state = luaL_newstate();
    if (!state || argc != 2 || strcmp(LUA_RELEASE, "Lua 5.1.5") != 0) return 1;
    luaL_openlibs(state);
    int status = luaL_dofile(state, argv[1]);
    if (status) fprintf(stderr, "%s\n", lua_tostring(state, -1));
    else printf("%s runtime check PASS\n", LUA_RELEASE);
    lua_close(state);
    return status ? 1 : 0;
}

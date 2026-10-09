import "host.flex";
fn df_get(url,path,sha) {
    if !h_exists(path) || !h_equal(h_sha(path),sha) {let args=h_args("curl","-fL","--retry","2",url,"-o");h_add(args,path);h_ok(args);}
    h_assert(h_equal(h_sha(path),sha),h_cat("Dependency checksum mismatch: ",path));return 0;
}
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc==1,"Usage: fetch-doom (from repository root)");h_mkdir("build");h_mkdir("build/doom-deps");
    df_get("https://codeload.github.com/ozkl/doomgeneric/tar.gz/dcb7a8dbc7a16ce3dda29382ac9aae9d77d21284","build/doom-deps/doomgeneric.tar.gz","1bd3f7f26220494159a38d71f2847ec81b58d6bbd7c7c8d81b08993018001148");
    df_get("https://raw.githubusercontent.com/nothings/stb/2c980bb59875b0d32144a71867fbdebb2f77cd20/stb_sprintf.h","build/doom-deps/stb_sprintf.h","e0b8c56e1084602290b9a17ef59f429b5293deb8cb9d8b0f20a14abc39b56520");
    df_get("https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip","build/doom-deps/freedoom.zip","3f9b264f3e3ce503b4fb7f6bdcb1f419d93c7b546f4df3e874dd878db9688f59");
    df_get("https://codeload.github.com/id-Software/DOOM/tar.gz/a77dfb96cb91780ca334d0d4cfd86957558007e0","build/doom-deps/id-doom.tar.gz","dc820b68a56cf174750c6c2db27109e4ac62d6694af3bdf6ced0a92cdb80a73b");
    h_ok(h_args("tar","-xzf","build/doom-deps/doomgeneric.tar.gz","-C","build/doom-deps",0));h_ok(h_args("unzip","-qo","build/doom-deps/freedoom.zip","-d","build/doom-deps",0));
    h_ok(h_args("tar","-xzf","build/doom-deps/id-doom.tar.gz","-C","build/doom-deps",0));
    h_print(1,"Verified pinned id Linux Doom, DoomGeneric, stb_sprintf and Freedoom 0.13.0 dependencies in build/doom-deps.\n");return 0;
}

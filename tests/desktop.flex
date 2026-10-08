import "../tools/qmp.flex";
global dt_checks=0;
fn dt_check(ok,message) {qt_assert(ok,message);dt_checks=dt_checks+1;return 0;}
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc==3 || argc==4,"Usage: test-desktop FLEX-COMPILER QEMU [FIRMWARE-DIRECTORY] (from repository root)");
    let compiler=h_real(load64(argv+8));let qemu=h_real(h_executable(load64(argv+16)));let firmware=0;if argc==4 {firmware=h_real(load64(argv+24));}
    h_mkdir("build/desktop-tests");let temp=h_temp();let image=h_join(temp,"desktop.bin");
    h_ok(h_args(compiler,"--target","baremetal-x86_64","desktop.flex","-o",image));qt_open(qemu,image,firmware,temp);
    qt_capture("build/desktop-tests/frame.ppm");qt_png("build/desktop-tests/welcome.png");dt_check(qt_pixel(600,500)==0x182537,"initial welcome window missing");dt_check(qt_pixel(355,710)==0x22334a,"dock not rendered");
    qt_key("f2");qt_pause(200);qt_until("Desktop opened Notes");qt_type("Hello FlexOS!\nSaved on bare metal.");qt_shortcut("ctrl","s");qt_until("Desktop saved /notes.txt");
    dt_check(h_has(qt_serial("cat /notes.txt"),"\nHello FlexOS!\nSaved on bare metal.\n"),"Notes keyboard input/save did not reach the filesystem");qt_png("build/desktop-tests/notes.png");
    qt_shortcut("ctrl","a");qt_type("alpha beta");qt_key("home");qt_type("X");qt_key("end");qt_key("backspace");qt_type("!");qt_shortcut("ctrl","s");
    dt_check(h_has(qt_serial("cat /notes.txt"),"\nXalpha bet!\n"),"selection, Home/End or Backspace failed");
    qt_shortcut("ctrl","a");qt_type("Hello FlexOS!\nSaved on bare metal.");qt_shortcut("ctrl","s");
    qt_move(500,184);qt_button(1);qt_move(420,244);qt_button(0);qt_pause(160);
    qt_capture("build/desktop-tests/frame.ppm");dt_check(qt_pixel(260,260)==0x182537,"window drag did not move the frame");
    qt_move(812,640);qt_button(1);qt_move(900,670);qt_button(0);qt_pause(160);qt_png("build/desktop-tests/windows.png");
    qt_capture("build/desktop-tests/frame.ppm");dt_check(qt_pixel(890,650)==0x182537,"resize did not extend the window body");
    qt_click(850,244);qt_until("Desktop toggled maximize Notes");qt_capture("build/desktop-tests/frame.ppm");dt_check(qt_pixel(20,100)==0x182537,"maximize did not expand the window");
    qt_click(942,68);qt_pause(160);qt_click(818,244);qt_until("Desktop minimized Notes");
    qt_capture("build/desktop-tests/frame.ppm");dt_check(qt_pixel(890,650)!=0x182537,"minimized window remained visible");
    qt_click(472,718);qt_until("Desktop opened Notes");qt_capture("build/desktop-tests/frame.ppm");dt_check(qt_pixel(890,650)==0x182537,"dock did not restore the window geometry");
    qt_click(882,244);qt_until("Desktop closed Notes");
    qt_click(310,718);qt_capture("build/desktop-tests/frame.ppm");dt_check(qt_pixel(300,430)==0x25364b,"launcher did not open");qt_png("build/desktop-tests/launcher.png");
    qt_click(400,484);qt_until("Desktop opened Files");qt_png("build/desktop-tests/files.png");
    qt_key("down");qt_key("ret");qt_pause(180);qt_until("Desktop opened Notes");
    qt_type(" Reopened.");qt_shortcut("ctrl","s");dt_check(h_has(qt_serial("cat /notes.txt"),"Saved on bare metal. Reopened.\n"),"Files did not reopen the saved note");
    qt_shortcut("ctrl","a");qt_type("Hello FlexOS!\nSaved on bare metal.");qt_shortcut("ctrl","s");
    qt_key("f4");qt_until("Desktop opened Terminal");qt_type("cat /notes.txt\n");qt_pause(250);qt_png("build/desktop-tests/terminal.png");
    qt_type("write /from-terminal.txt 'Terminal works'\n");qt_pause(150);
    dt_check(h_has(qt_serial("cat /from-terminal.txt"),"\nTerminal works\n"),"graphical Terminal did not dispatch filesystem commands");
    qt_type("mkdir /projects\n");qt_type("exit\n");qt_until("Desktop closed Terminal");
    qt_key("f3");qt_key("down");qt_key("down");qt_key("ret");qt_pause(100); // enter projects/ (fourth root entry)
    qt_click(370,196);qt_pause(120);qt_type("Created in Files.");qt_shortcut("ctrl","s");
    dt_check(h_has(qt_serial("cat '/projects/Note 1.txt'"),"\nCreated in Files.\n"),"Files navigation/New note did not create a file in its directory");
    qt_type(" Draft");qt_key("f3");qt_click(370,196);qt_pause(120);qt_shortcut("ctrl","s");
    dt_check(h_has(qt_serial("cat '/projects/Note 1.txt'"),"Created in Files. Draft\n"),"New note discarded an unsaved draft");
    dt_check(h_has(qt_serial("cat '/projects/Note 2.txt'"),"Error: path not found"),"New note created a file while another note was unsaved");
    qt_shortcut("alt","tab");qt_png("build/desktop-tests/final.png");
    qt_click(950,20);qt_click(900,86);qt_until("FlexOS desktop halted.");
    let registers=qt_execute("human-monitor-command","{\"command-line\":\"info registers\"}");dt_check(h_has(registers,"CPL=0") && h_has(registers,"CS64") && h_has(registers,"HLT=1"),"desktop shutdown did not halt a native ring-0 guest");
    qt_stop();h_remove(temp);h_print(1,h_cat3("PASS: ",h_int(dt_checks)," graphical desktop framebuffer/PS2/windows/editor/files/terminal checks in QEMU\n"));return 0;
}

#ifdef __SWITCH__
#include <port/switch/SwitchImpl.h>
#include <switch.h>
#include <cstdio>

namespace Ship {
namespace Switch {

void Init(SwitchPhase phase) {
    if (phase == PreInitPhase) {
        // Do not call consoleInit here - it takes over the NWindow
        // and prevents SDL from creating a GL context.
        socketInitializeDefault();
        nxlinkStdio();
    }
}

void PrintErrorMessageToScreen(const char* msg) {
    // In a graphical app, just log to stdout (nxlink)
    printf("ERROR: %s\n", msg);
}

} // namespace Switch
} // namespace Ship
#endif

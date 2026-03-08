#pragma once

namespace Ship {
namespace Switch {

enum SwitchPhase {
    PreInitPhase,
    PostInitPhase
};

void Init(SwitchPhase phase);
void PrintErrorMessageToScreen(const char* msg);

} // namespace Switch
} // namespace Ship

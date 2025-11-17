#import "VMHookAudioUnit.hpp"

double auCurScale = 1;
std::unordered_map<void *, AURenderCallback> inRefCon_to_orig_map;

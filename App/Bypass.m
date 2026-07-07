#import "Bypass.h"
#import <objc/runtime.h>
#import <LocalAuthentication/LocalAuthentication.h>

typedef void (^LAReplyBlock)(BOOL success, NSError *error);

static BOOL gInstalled = NO;

static void swizzled_evaluatePolicy(id self, SEL _cmd,
                                    NSInteger policy,
                                    NSString *reason,
                                    LAReplyBlock reply) {
    NSLog(@"[Bypass] evaluatePolicy intercepted (policy=%ld) --> forging reply(YES, nil)", (long)policy);
    if (reply) {
        reply(YES, nil);
    }
}

static BOOL swizzled_canEvaluatePolicy(id self, SEL _cmd,
                                       NSInteger policy,
                                       NSError **error) {
    NSLog(@"[Bypass] canEvaluatePolicy intercepted --> forcing YES");
    if (error) { *error = nil; }
    return YES;
}

static void swizzle(Class cls, SEL sel, IMP newImp) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) {
        NSLog(@"[Bypass] method %@ not found on %@", NSStringFromSelector(sel), cls);
        return;
    }
    method_setImplementation(m, newImp);
    NSLog(@"[Bypass] swizzled %@", NSStringFromSelector(sel));
}

void InstallFaceIDBypass(void) {
    if (gInstalled) { return; }
    gInstalled = YES;

    Class LAContext = objc_getClass("LAContext");
    if (!LAContext) {
        NSLog(@"[Bypass] LAContext not present");
        return;
    }
    swizzle(LAContext, @selector(evaluatePolicy:localizedReason:reply:), (IMP)swizzled_evaluatePolicy);
    swizzle(LAContext, @selector(canEvaluatePolicy:error:), (IMP)swizzled_canEvaluatePolicy);
    NSLog(@"[Bypass] installed in-process.");
}

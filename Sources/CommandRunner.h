#import <Foundation/Foundation.h>

typedef void (^CommandCompletion)(int exitCode, NSString *message);

@interface CommandRunner : NSObject
+ (void)runExecutableCandidates:(NSArray<NSString *> *)candidates arguments:(NSArray<NSString *> *)arguments completion:(CommandCompletion)completion;
@end

#import <Foundation/Foundation.h>

@interface SystemInfo : NSObject
+ (NSArray<NSArray<NSDictionary<NSString *, NSString *> *> *> *)overviewSections;
+ (NSString *)jailbreakRoot;
+ (BOOL)isRootless;
@end

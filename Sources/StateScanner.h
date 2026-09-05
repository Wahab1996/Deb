#import <Foundation/Foundation.h>
@class AppRecord, InspectionFinding;

@interface StateScanner : NSObject
+ (NSArray<InspectionFinding *> *)scanApp:(AppRecord *)app;
+ (NSArray<InspectionFinding *> *)scanStoreKitCluesForApp:(AppRecord *)app;
+ (NSDictionary<NSString *, NSString *> *)snapshotApp:(AppRecord *)app;
+ (NSArray<InspectionFinding *> *)diffFrom:(NSDictionary<NSString *, NSString *> *)before
                                        to:(NSDictionary<NSString *, NSString *> *)after;
@end

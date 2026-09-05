#import <Foundation/Foundation.h>

@interface AppRecord : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, strong) NSURL *bundleURL;
@property (nonatomic, strong) NSURL *dataURL;
@property (nonatomic, copy) NSString *version;
@end

#import <Foundation/Foundation.h>

@interface InspectionFinding : NSObject
@property (nonatomic, copy) NSString *category;
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, copy) NSString *reason;
@property (nonatomic, assign) NSInteger score;
- (NSDictionary *)dictionaryRepresentation;
+ (instancetype)fromDictionary:(NSDictionary *)dictionary;
@end

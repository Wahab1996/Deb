#import "InspectionFinding.h"

@implementation InspectionFinding
- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"category": self.category ?: @"",
        @"filePath": self.filePath ?: @"",
        @"keyPath": self.keyPath ?: @"",
        @"value": self.value ?: @"",
        @"reason": self.reason ?: @"",
        @"score": @(self.score)
    };
}
+ (instancetype)fromDictionary:(NSDictionary *)d {
    InspectionFinding *f = [InspectionFinding new];
    f.category = d[@"category"] ?: @"";
    f.filePath = d[@"filePath"] ?: @"";
    f.keyPath = d[@"keyPath"] ?: @"";
    f.value = d[@"value"] ?: @"";
    f.reason = d[@"reason"] ?: @"";
    f.score = [d[@"score"] integerValue];
    return f;
}
@end

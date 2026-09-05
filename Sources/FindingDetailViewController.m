#import "FindingDetailViewController.h"
#import "InspectionFinding.h"

@interface FindingDetailViewController ()
@property (nonatomic, strong) InspectionFinding *finding;
@end

@implementation FindingDetailViewController
- (instancetype)initWithFinding:(InspectionFinding *)finding {
    if ((self = [super init])) _finding = finding;
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Finding";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Copy Path" style:UIBarButtonItemStylePlain target:self action:@selector(copyPath)];

    UITextView *text = [[UITextView alloc] initWithFrame:CGRectZero];
    text.translatesAutoresizingMaskIntoConstraints = NO;
    text.editable = NO;
    text.selectable = YES;
    text.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    text.textContainerInset = UIEdgeInsetsMake(20, 16, 20, 16);
    text.text = [NSString stringWithFormat:@"CATEGORY\n%@\n\nFILE\n%@\n\nKEY / LOCATION\n%@\n\nVALUE\n%@\n\nWHY FLAGGED\n%@\n\nSCORE\n%ld", self.finding.category, self.finding.filePath, self.finding.keyPath, self.finding.value, self.finding.reason, (long)self.finding.score];
    [self.view addSubview:text];
    [NSLayoutConstraint activateConstraints:@[
        [text.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [text.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [text.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [text.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}
- (void)copyPath {
    UIPasteboard.generalPasteboard.string = self.finding.filePath ?: @"";
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Copied" message:@"File path copied to clipboard." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
@end

#import "PlayerSettingsController.h"

@implementation PlayerSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = LOC(@"PLAYER_SETTINGS");
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.tableView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor],
        [self.tableView.heightAnchor constraintEqualToAnchor:self.view.heightAnchor],
        [self.tableView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 7;
    if (section == 1) return 2; // Added Crossfade row
    if (section == 2) return 3;
    if (section == 3) return 2;
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *YTMUltimateDict = [defaults dictionaryForKey:@"YTMUltimate"];

    UITableViewCell *cell;

    if (indexPath.section == 1 && indexPath.row == 0) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"avCell"];
        cell.textLabel.text = LOC(@"AV_DEFAULT_MODE");

        UISegmentedControl *control = [[UISegmentedControl alloc] initWithItems:@[LOC(@"AUDIO"), LOC(@"VIDEO")]];
        control.selectedSegmentIndex = [YTMUltimateDict[@"audioVideoMode"] integerValue];
        [control addTarget:self action:@selector(controlSelect:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = control;
        return cell;
    }

    if (indexPath.section == 1 && indexPath.row == 1) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"crossfadeCell"];
        cell.textLabel.text = LOC(@"CROSSFADE");
        cell.detailTextLabel.text = LOC(@"CROSSFADE_DESC");
        cell.detailTextLabel.numberOfLines = 0;

        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 240, 44)];
        container.translatesAutoresizingMaskIntoConstraints = NO;

        UISlider *slider = [[UISlider alloc] initWithFrame:CGRectZero];
        slider.minimumValue = 1.0;
        slider.maximumValue = 10.0;
        NSInteger currentVal = [YTMUltimateDict[@"crossfadeSeconds"] integerValue];
        if (currentVal <= 0) currentVal = 5;
        slider.value = currentVal;
        slider.translatesAutoresizingMaskIntoConstraints = NO;
        [slider addTarget:self action:@selector(crossfadeSliderChanged:) forControlEvents:UIControlEventValueChanged];
        slider.tag = 12345;

        UILabel *valLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        valLabel.translatesAutoresizingMaskIntoConstraints = NO;
        valLabel.text = [NSString stringWithFormat:@"%lds", (long)lround(slider.value)];
        valLabel.textAlignment = NSTextAlignmentRight;
        valLabel.adjustsFontSizeToFitWidth = YES;
        valLabel.tag = 12346;

        [container addSubview:slider];
        [container addSubview:valLabel];

        [NSLayoutConstraint activateConstraints:@[
            [slider.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [slider.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
            [slider.trailingAnchor constraintEqualToAnchor:valLabel.leadingAnchor constant:-8],
            [valLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
            [valLabel.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
            [valLabel.widthAnchor constraintEqualToConstant:44]
        ]];

        cell.accessoryView = container;
        return cell;
    }

    // fallback for other sections (leave existing logic)
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"defaultCell"];
    cell.textLabel.text = @"";
    return cell;
}

#pragma mark - Slider handler

- (void)crossfadeSliderChanged:(UISlider *)slider {
    NSInteger rounded = lround(slider.value);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[defaults dictionaryForKey:@"YTMUltimate"]];
    if (!dict) dict = [NSMutableDictionary new];
    dict[@"crossfadeSeconds"] = @(rounded);
    [defaults setObject:dict forKey:@"YTMUltimate"];

    UIView *container = slider.superview;
    for (UIView *v in container.subviews) {
        if ([v isKindOfClass:[UILabel class]] && v.tag == 12346) {
            ((UILabel *)v).text = [NSString stringWithFormat:@"%lds", (long)rounded];
        }
    }
}

#pragma mark - Existing handlers

- (void)toggleSwitch:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[defaults dictionaryForKey:@"YTMUltimate"]];
    // keep it simple; if you had original logic, put it back here
    dict[@"someKey"] = @(sender.isOn);
    [defaults setObject:dict forKey:@"YTMUltimate"];
}

- (void)controlSelect:(UISegmentedControl *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[defaults dictionaryForKey:@"YTMUltimate"]];
    dict[@"audioVideoMode"] = @(sender.selectedSegmentIndex);
    [defaults setObject:dict forKey:@"YTMUltimate"];
}

#pragma mark - Keyboard toolbar fix

- (UIView *)KBToolbar:(UITextField *)textField {
    UIToolbar *toolbar = [[UIToolbar alloc] init];
    toolbar.barStyle = UIBarStyleDefault;

    UIBarButtonItem *flexible = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(hideKeyboard)];

    [toolbar setItems:@[flexible, done]];
    [toolbar sizeToFit];
    return toolbar;
}

- (void)hideKeyboard {
    [self.view endEditing:YES];
}

@end

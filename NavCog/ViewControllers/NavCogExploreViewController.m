/*******************************************************************************
 * Copyright (c) 2015 Chengxiong Ruan
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

#import "NavCogExploreViewController.h"

@interface NavCogExploreViewController ()

@property (strong, nonatomic) UIView *blankView;
@property (strong, nonatomic) UIWebView *webView;

@end

@implementation NavCogExploreViewController

+ (instancetype)sharedNavCogExploreViewController {
    static NavCogExploreViewController *ctrl = nil;
    if (ctrl == nil) {
        ctrl = [[NavCogExploreViewController alloc] init];
    }
    return ctrl;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.frame = [[UIScreen mainScreen] bounds];
    self.view.bounds = [[UIScreen mainScreen] bounds];
    self.view.backgroundColor = [UIColor clearColor];
    [self setupUI];
}

- (void)setupUI {
    // google map web view
    _webView = [[UIWebView alloc] init];
    _webView.frame = [[UIScreen mainScreen] bounds];
    _webView.bounds = [[UIScreen mainScreen] bounds];
    NSURL *pageURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"NavCogMapView" ofType:@"html" inDirectory:@"NavCogMapView"]];
    _webView.delegate = self;
    [self.view addSubview:_webView];
    [_webView loadRequest:[[NSURLRequest alloc] initWithURL:pageURL]];
    
    // blank view to block touch from google map
    _blankView = [[UIView alloc] init];
    _blankView.frame = [[UIScreen mainScreen] bounds];
    _blankView.bounds = [[UIScreen mainScreen] bounds];
    _blankView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_blankView];
    
    // buttons
    float sw = [[UIScreen mainScreen] bounds].size.width;
    float sh = [[UIScreen mainScreen] bounds].size.height;
    float bw = sw / 3;
    float bh = sh / 3;
    
    // point of interest button
    UIButton *poiButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [poiButton addTarget:self action:@selector(playPOIInformation) forControlEvents:UIControlEventTouchUpInside];
    poiButton.frame = CGRectMake(0, 0, bw, bh);
    poiButton.bounds = CGRectMake(0, 0, bw, bh);
    poiButton.layer.cornerRadius = 3;
    poiButton.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.6];
    poiButton.layer.borderWidth = 2.0;
    poiButton.layer.borderColor = [UIColor blackColor].CGColor;
    poiButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    poiButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [poiButton setTitle:NSLocalizedString(@"Play POI", @"HTML Label for POI button in view")forState:UIControlStateNormal];
    [poiButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [poiButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    [self.view addSubview:poiButton];
    
    // stop exploration button
    UIButton *stopButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [stopButton addTarget:self action:@selector(stopExploration) forControlEvents:UIControlEventTouchUpInside];
    stopButton.frame = CGRectMake(sw -bw, sh - bh, bw, bh);
    stopButton.bounds = CGRectMake(0, 0, bw, bh);
    stopButton.layer.cornerRadius = 3;
    stopButton.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.6];
    stopButton.layer.borderWidth = 2.0;
    stopButton.layer.borderColor = [UIColor blackColor].CGColor;
    stopButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    stopButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [stopButton setTitle:NSLocalizedString(@"Stop\nExploration", @"HTML Label for stop exploration button in view") forState:UIControlStateNormal];
    [stopButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [stopButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    [self.view addSubview:stopButton];
}

- (void)runCmdWithString:(NSString *)str {
    [_webView stringByEvaluatingJavaScriptFromString:str];
}

// web view delegate methods
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [_delegate webViewLoaded];
}

- (void)stopExploration {
    [_delegate didTriggerStopExploration];
}

- (void)playPOIInformation {
    [_delegate didTriggerPOI];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

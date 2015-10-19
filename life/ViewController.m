//
//  ViewController.m
//  life
//
//  Created by Dmitrii Platov on 10/15/15.
//  Copyright © 2015 dplatov. All rights reserved.
//

#import "ViewController.h"
#import "OpenGLView.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet OpenGLView *lifeView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
#pragma mark user action handled
- (IBAction)start:(UIButton*)sender {
    if([self.lifeView runTimer]){
        [sender setTitle:@"Stop" forState:UIControlStateNormal];
    }else{
        [sender setTitle:@"Start" forState:UIControlStateNormal];
    }
    
}

- (IBAction)clear {
    [self.lifeView clearField];
}

- (IBAction)next {
    [self.lifeView nextGeneration];
}
- (IBAction)about {
   [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life"]];
}

@end

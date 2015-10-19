//
//  OpenGLView.h
//  life
//
//  Created by Dmitrii Platov on 10/15/15.
//  Copyright © 2015 dplatov. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OpenGLView : UIView

@property (readonly) NSInteger cellCount;

- (void)nextGeneration;
- (void)clearField;
- (BOOL)runTimer;
@end

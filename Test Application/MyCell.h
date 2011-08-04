//
//  MyCell.h
//  LKWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/02.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MyCell : UITableViewCell {
    UIActivityIndicatorView *indicator;
    UILabel *label;
    UILabel *title;
    UIProgressView *progressView;
    UIButton *cancelButton;
    UIButton *stopStartButton;
}

@property (nonatomic, retain) IBOutlet UIButton *stopStartButton;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *indicator;
@property (nonatomic, retain) IBOutlet UILabel *label;
@property (nonatomic, retain) IBOutlet UILabel *title;
@property (nonatomic, retain) IBOutlet UIProgressView *progressView;
@property (nonatomic, retain) IBOutlet UIButton *cancelButton;

@end

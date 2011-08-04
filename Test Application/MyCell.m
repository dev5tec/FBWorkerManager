//
//  MyCell.m
//  LKWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/02.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "MyCell.h"

@implementation MyCell
@synthesize stopStartButton;
@synthesize indicator;
@synthesize label;
@synthesize title;
@synthesize progressView;
@synthesize cancelButton;

/*
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}
*/

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)dealloc {
    [indicator release];
    [label release];
    [title release];
    [progressView release];
    [stopStartButton release];
    [cancelButton release];
    [super dealloc];
}
@end

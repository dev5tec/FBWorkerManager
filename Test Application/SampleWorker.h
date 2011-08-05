//
//  Sample.h
//  FBWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/03.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FBWorker.h"

@interface SampleWorker : NSObject <FBWorker> 
@property (nonatomic, copy) NSString* title;
@property (nonatomic, retain) NSDate* time;
@property (nonatomic, assign) CGFloat progress;
@end

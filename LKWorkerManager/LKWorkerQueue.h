//
//  LKWorkerSource.h
//  LKWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/01.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LKWorker.h"

@protocol LKWorkerQueue <NSObject>

// NOTE: must be thread-safe
- (NSUInteger)count;
- (id <LKWorker>)nextWorker;

@end

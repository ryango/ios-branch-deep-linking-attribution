/**
 @file          NSError+Branch.m
 @package       Branch-SDK
 @brief         Branch errors.

 @author        Qinwei Gong
 @date          November 2014
 @copyright     Copyright © 2014 Branch. All rights reserved.
*/

#import "NSError+Branch.h"

__attribute__((constructor)) void BNCForceNSErrorCategoryToLoad(void) {
    // Nothing here, but forces linker to load the category.
}

@implementation NSError (Branch)

+ (NSString *)bncErrorDomain {
    return @"io.branch.sdk.error";
}

// Legacy error messages
+ (NSString *)messageForCode:(BNCErrorCode)code {
    static NSMutableDictionary<NSNumber *, NSString *> *messages;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        messages = [NSMutableDictionary<NSNumber *, NSString *> new];
        [messages setObject:@"The Branch user session has not been initialized." forKey:@(BNCInitError)];
        [messages setObject:@"A resource with this identifier already exists." forKey:@(BNCDuplicateResourceError)];
        [messages setObject:@"The network request was invalid." forKey:@(BNCBadRequestError)];
        [messages setObject:@"Trouble reaching the Branch servers, please try again shortly." forKey:@(BNCServerProblemError)];
        [messages setObject:@"Can't log error messages because the logger is set to nil." forKey:@(BNCNilLogError)];
        [messages setObject:@"Incompatible version." forKey:@(BNCVersionError)];
        [messages setObject:@"The underlying network service does not conform to the BNCNetworkOperationProtocol." forKey:@(BNCNetworkServiceInterfaceError)];
        [messages setObject:@"Public key is not an SecKeyRef type." forKey:@(BNCInvalidNetworkPublicKeyError)];
        [messages setObject:@"A canonical identifier or title are required to uniquely identify content." forKey:@(BNCContentIdentifierError)];
        [messages setObject:@"The Core Spotlight indexing service is not available on this device." forKey:@(BNCSpotlightNotAvailableError)];
        [messages setObject:@"Spotlight indexing requires a title." forKey:@(BNCSpotlightTitleError)];
        [messages setObject:@"The Spotlight identifier is required to remove indexing from spotlight." forKey:@(BNCSpotlightIdentifierError)];
        [messages setObject:@"Spotlight cannot remove publicly indexed content." forKey:@(BNCSpotlightPublicIndexError)];
        [messages setObject:@"User tracking is disabled and the request is not allowed" forKey:@(BNCTrackingDisabledError)];
    });
    
    NSString *errorMessage = [messages objectForKey:@(code)];
    if (!errorMessage) {
        errorMessage = @"Branch encountered an error.";
    }
    return errorMessage;
}

+ (NSError *)branchErrorWithCode:(BNCErrorCode)errorCode error:(NSError *)error localizedMessage:(NSString * _Nullable)message {
    NSMutableDictionary *userInfo = [NSMutableDictionary new];

    NSString *localizedString = [self messageForCode:errorCode];
    if (localizedString) {
        userInfo[NSLocalizedDescriptionKey] = localizedString;
    }
    
    if (message) {
        userInfo[NSLocalizedFailureReasonErrorKey] = message;
    }
    
    if (error) {
        userInfo[NSUnderlyingErrorKey] = error;
        if (!userInfo[NSLocalizedFailureReasonErrorKey] && error.localizedDescription) {
            userInfo[NSLocalizedFailureReasonErrorKey] = error.localizedDescription;
        }
    }

    return [NSError errorWithDomain:[self bncErrorDomain] code:errorCode userInfo:userInfo];
}

+ (NSError *) branchErrorWithCode:(BNCErrorCode)errorCode {
    return [NSError branchErrorWithCode:errorCode error:nil localizedMessage:nil];
}

+ (NSError *) branchErrorWithCode:(BNCErrorCode)errorCode error:(NSError * _Nullable)error {
    return [NSError branchErrorWithCode:errorCode error:error localizedMessage:nil];
}

+ (NSError *) branchErrorWithCode:(BNCErrorCode)errorCode localizedMessage:(NSString * _Nullable)message {
    return [NSError branchErrorWithCode:errorCode error:nil localizedMessage:message];
}

+ (BOOL)branchDNSBlockingError:(NSError *)error {
    if (error) {
        NSError *underlyingError = error.userInfo[@"NSUnderlyingError"];
        if (underlyingError) {

            /**
             Check if an NSError was likely caused by a DNS sinkhole, such as Pi-hole.
             The OS level logs will show that the IP address that failed is all 0's, however App level logs will not contain that information.
              
             `Domain=kCFErrorDomainCFNetwork Code=-1000` - Connection failed due to a malformed URL. A bit misleading since Ad blockers DNS resolve the URL as 0.0.0.0.
             https://developer.apple.com/documentation/cfnetwork/cfnetworkerrors/kcfurlerrorbadurl?language=objc
             
             `_kCFStreamErrorDomainKey=1` Error domain is a POSIX error.
             https://opensource.apple.com/source/CF/CF-550.13/CFStream.h.auto.html
                 
             `_kCFStreamErrorCodeKey=22` POSIX error is invalid argument. In this case the IP address is 0.0.0.0, which is invalid.
             https://opensource.apple.com/source/xnu/xnu-792/bsd/sys/errno.h.auto.html
             */
            BOOL isCFErrorDomainCFNetwork = [((NSString *)kCFErrorDomainCFNetwork) isEqualToString:underlyingError.domain];
            BOOL isCodeMalFormedURL = [@(-1000) isEqual:@(underlyingError.code)];
            
            BOOL isErrorDomainPosix =  [@(1) isEqual:error.userInfo[@"_kCFStreamErrorDomainKey"]];
            BOOL isPosixInvalidArgument = [@(22) isEqual:error.userInfo[@"_kCFStreamErrorCodeKey"]];
            
            if (isCFErrorDomainCFNetwork && isCodeMalFormedURL && isErrorDomainPosix && isPosixInvalidArgument) {
                return YES;
            }
        }
    }
    return NO;
}

@end

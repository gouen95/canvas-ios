//
//  CKAPICredentials.m
//  CanvasKit
//
//  Created by BJ Homer on 6/21/12.
//  Copyright (c) 2012 Instructure, Inc. All rights reserved.
//

#import "CKAPICredentials.h"
#import "KeychainStorage.h"
#import <Security/Security.h>


static NSString * const ServiceName = @"com.instructure.shared-credentials";
static NSString * const KeychainGroupIdentifier = @"8MKNFMCD9M.com.instructure.shared-credentials";

static NSString * const UsernameIdentifierKey = @"UserName";
static NSString * const UserIDIdentifierKey = @"UserID";
static NSString * const HostnameIdentifierKey = @"Hostname";
static NSString * const APIProtocolIdentifierKey = @"APIProtocol";
static NSString * const AccessTokenIdentifierKey = @"AccessToken";
static NSString * const KeychainDataVersionKey = @"DataVersion";
static NSString * const ActAsID = @"ActAsID";

@interface CKAPICredentials ()
@property int keychainDataVersion;
@end

@implementation CKAPICredentials

+ (int)currentKeychainDataVersion
{    
    // Version 2
    // Keychain: {
    //   kSecattrClassKey:    kSecAttrClassGenericPassword
    //   kSecAttrService:     "com.instructure.shared-credentials"
    //   kSecAttrAccessGroup: "8MKNFMCD9M.com.instructure.shared-credentials"
    //   kSecValueData:       NSKeyedArchiverData({
    //                          UserName:    @"john.appleseed@example.com",
    //                          UserID:      @12345,
    //                          Hostname:    @"canvas.instructure.com",
    //                          APIProtocol: @"https",
    //                          AccessToken: @"<some access token>",
    //                          DataVersion: @2
    //                        })
    // }
    
    return 2;
}

+ (NSMutableDictionary *)_keychainSearchDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    
    dict[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    dict[(__bridge id)kSecAttrService] = ServiceName;
#if TARGET_IPHONE_SIMULATOR
    // Can't use keychain groups, because simulator apps aren't signed.
#else
    [dict setObject:KeychainGroupIdentifier forKey:(__bridge id)kSecAttrAccessGroup];
#endif
    
    
    return dict;
}

+ (CKAPICredentials *)apiCredentialsFromKeychain
{
    
    NSMutableDictionary *searchDictionary = [CKAPICredentials _keychainSearchDictionary];

    searchDictionary[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    searchDictionary[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    CFTypeRef cfResultData = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)searchDictionary, &cfResultData);
    if (status == errSecItemNotFound) {
        [self _migrateToSharedKeychain];
        status = SecItemCopyMatching((__bridge CFDictionaryRef)searchDictionary, &cfResultData);
    }
    
    if (status != errSecSuccess && status != errSecItemNotFound) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Error reading credentials: %@", error);
        return nil;
    }
    
    NSData *resultData = CFBridgingRelease(cfResultData);
    if (resultData == nil) {
        return nil;
    }
    else {
        NSDictionary *result = [NSKeyedUnarchiver unarchiveObjectWithData:resultData];
        
        CKAPICredentials *creds = [CKAPICredentials new];
        creds.userName = result[UsernameIdentifierKey];
        creds.userIdent = [result[UserIDIdentifierKey] unsignedLongLongValue];
        creds.hostname = result[HostnameIdentifierKey];
        creds.apiProtocol = result[APIProtocolIdentifierKey];
        creds.accessToken = result[AccessTokenIdentifierKey];
        creds.keychainDataVersion = [result[KeychainDataVersionKey] intValue];
        creds.actAsId = result[ActAsID];
        if ([creds.actAsId isEqualToString:@""]) {
            // CanvasAPI uses nil to represent no user, but we can't save nil to the keychain,
            // so instead we use empty string.
            creds.actAsId = nil;
        }
        
        return creds;
    }
}

- (id)init
{
    self = [super init];
    if (self) {
        _keychainDataVersion = 2;
        
    }
    return self;
}


- (void)saveToKeychain
{
    // If there is no username don't save creds
    if (!_userName) {
        return;
    }
    
    NSMutableDictionary *dictToSave = [NSMutableDictionary dictionary];
    dictToSave[UsernameIdentifierKey] = _userName;
    dictToSave[UserIDIdentifierKey] = @(_userIdent);
    dictToSave[HostnameIdentifierKey] = _hostname;
    dictToSave[APIProtocolIdentifierKey] = _apiProtocol;
    dictToSave[AccessTokenIdentifierKey] = _accessToken;
    dictToSave[KeychainDataVersionKey] = @(_keychainDataVersion);
    dictToSave[ActAsID] = _actAsId ?: @"";
    
    NSNumber *currentVersion = @([CKAPICredentials currentKeychainDataVersion]);
    dictToSave[KeychainDataVersionKey] = currentVersion;
    
    NSData *dataToSave = [NSKeyedArchiver archivedDataWithRootObject:dictToSave];
    
    NSMutableDictionary *queryDictionary = [CKAPICredentials _keychainSearchDictionary];

    NSMutableDictionary *attrsDictionary = [NSMutableDictionary new];
    attrsDictionary[(__bridge id)kSecValueData] = dataToSave;
    
    OSStatus status = 0;
    status = SecItemUpdate((__bridge CFTypeRef)queryDictionary, (__bridge CFTypeRef)attrsDictionary);
    if (status == errSecItemNotFound) {
        [attrsDictionary addEntriesFromDictionary:queryDictionary];
        status = SecItemAdd((__bridge CFTypeRef)attrsDictionary, NULL);
    }
    
    if (status != errSecSuccess) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Error saving credentials: %@", error);
    }
}

+ (void)deleteCredentialsFromKeychain
{
    NSDictionary *searchDictionary = [self _keychainSearchDictionary];
    OSStatus status = SecItemDelete((__bridge CFTypeRef)searchDictionary);
    if (status != errSecSuccess) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Error clearing keychain: %@", error);
    }
}

- (BOOL)isValid
{
    return _userName && _userIdent && _hostname && _apiProtocol && _accessToken;
}


+ (void)_migrateToSharedKeychain
{    
    /*
     We used to store things in user defaults like this:
     
     // Version 0
     // {
     //   CKCanvasUserInfoKey: {
     //     @"CKCanvasUserNameKey":    @"john.appleseed@example.com",
     //     @"CKCanvasUserIDKey":      @12345,
     //     @"CKCanvasAccessTokenKey": <some access token as an NSString>
     //   }
     // }
     
     Then we realized we needed to store the hostname, and that
     it was dumb to store the access token in NSUserDefaults, so
     we moved the access token to the keychain, with the following attributes:
     
     // Version 1
     // Keychain: {
     //   kSecattrClassKey: kSecAttrClassGenericPassword
     //   kSecAttrService: [[NSBundle mainBundle] bundleIdentifier]
     //   kSecAttrGeneric: utf8("CKCanvasAccessTokenKey")
     //   kSecAttrAccount: utf8("CKCanvasAccessTokenKey")
     //   kSecValueData:   utf8(<access token>)
     // }
     // NSUserDefaults: {
     //   CKCanvasUserInfoVersionKey:  @1,
     //   CKCanvasUserInfoKey: {
     //     @"CKCanvasUserNameKey":    @"john.appleseed@example.com",
     //     @"CKCanvasUserIDKey":      @12345,
     //     @"CKCanvasHostNameKey":    @"canvas.instructure.com",
     //     @"CKCanvasAPIProtocolKey": @"https",
     //   }
     // }
     
     Then, however, we wanted to share items between our apps, so we moved
     everything to a shared keychain group. As of version 2, everything is
     stored in the keychain, and none of the above should exist in NSUserDefaults
     anymore.
     
     // Version 2
     // Keychain: {
     //   kSecattrClassKey:    kSecAttrClassGenericPassword
     //   kSecAttrService:     "com.instructure.shared-credentials"
     //   kSecAttrAccessGroup: "8MKNFMCD9M.com.instructure.shared-credentials"
     //   kSecValueData:       NSKeyedArchiverData({
     //                          UserName:    @"john.appleseed@example.com",
     //                          UserID:      @12345,
     //                          Hostname:    @"canvas.instructure.com",
     //                          APIProtocol: @"https",
     //                          AccessToken: @"<some access token>",
     //                          DataVersion: @2
     //                        })
     // }
     
     */
    
    NSDictionary *defaults = [[NSUserDefaults standardUserDefaults]
                              dictionaryForKey:CKCanvasUserInfoKey];
    
    
    NSString *serviceName = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
    KeychainStorage *keychainStorage = [[KeychainStorage alloc] initWithServiceName:serviceName];
    
    NSString *accessToken = [keychainStorage valueForIdentifier:CKCanvasAccessTokenKey];
    if (!accessToken) {
        accessToken = defaults[CKCanvasAccessTokenKey];
    }
    
    CKAPICredentials *creds = [CKAPICredentials new];
    creds.userName = defaults[CKCanvasUserNameKey];
    creds.userIdent = [defaults[CKCanvasUserIDKey] unsignedLongLongValue];
    creds.hostname = defaults[CKCanvasHostnameKey];
    creds.apiProtocol = defaults[CKCanvasAPIProtocolKey];
    creds.accessToken = accessToken;
    if ([defaults[ActAsID] isEqualToString:@""]) {
        creds.actAsId = nil;
    }
    else {
        creds.actAsId = defaults[ActAsID];
    }
    
    if ([creds isValid] == NO) {
        // We don't have enough information, don't bother saving anything
        return;
    }
    else {
        [creds saveToKeychain];
        [keychainStorage deleteKeychainValue:CKCanvasAccessTokenKey];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CKCanvasUserInfoVersionKey];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CKCanvasUserInfoKey];
    }
}


#pragma mark - NSObject overrides


- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[CKAPICredentials class]] == NO) {
        return NO;
    }
    
    BOOL isEqual = YES;
    CKAPICredentials *other = object;
    
    if ([_userName isEqualToString:other.userName] == NO) {
        isEqual = NO;
    }
    if (_userIdent != other.userIdent) {
        isEqual = NO;
    }
    if ([_hostname isEqualToString:other.hostname] == NO) {
        isEqual = NO;
    }
    if ([_apiProtocol isEqualToString:other.apiProtocol] == NO) {
        isEqual = NO;
    }
    if ([_accessToken isEqualToString:other.accessToken] == NO) {
        isEqual = NO;
    }
    if (_keychainDataVersion != other.keychainDataVersion) {
        isEqual = NO;
    }
    if ((_actAsId || other.actAsId) && [_actAsId isEqualToString:other.actAsId] == NO) {
        isEqual = NO;
    }
    return isEqual;
}

- (NSUInteger)hash
{
    NSUInteger hash = [_userName hash];
    hash ^= _userIdent;
    hash ^= [_hostname hash];
    hash ^= [_apiProtocol hash];
    hash ^= [_accessToken hash];
    hash ^= _keychainDataVersion;
    hash ^= [_actAsId hash];
    return hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ (userName: %@, accessToken: %@)", [super description], _userName, _accessToken];
}

@end

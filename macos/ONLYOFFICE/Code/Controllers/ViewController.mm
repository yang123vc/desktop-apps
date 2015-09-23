/*
 * (c) Copyright Ascensio System SIA 2010-2016
 *
 * This program is a free software product. You can redistribute it and/or
 * modify it under the terms of the GNU Affero General Public License (AGPL)
 * version 3 as published by the Free Software Foundation. In accordance with
 * Section 7(a) of the GNU AGPL its Section 15 shall be amended to the effect
 * that Ascensio System SIA expressly excludes the warranty of non-infringement
 * of any third-party rights.
 *
 * This program is distributed WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR  PURPOSE. For
 * details, see the GNU AGPL at: http://www.gnu.org/licenses/agpl-3.0.html
 *
 * You can contact Ascensio System SIA at Lubanas st. 125a-25, Riga, Latvia,
 * EU, LV-1021.
 *
 * The  interactive user interfaces in modified source and object code versions
 * of the Program must display Appropriate Legal Notices, as required under
 * Section 5 of the GNU AGPL version 3.
 *
 * Pursuant to Section 7(b) of the License you must retain the original Product
 * logo when distributing the program. Pursuant to Section 7(e) we decline to
 * grant you any rights under trademark law for use of our trademarks.
 *
 * All the Product's GUI elements, including illustrations and icon sets, as
 * well as technical writing content are licensed under the terms of the
 * Creative Commons Attribution-ShareAlike 4.0 International. See the License
 * terms at http://creativecommons.org/licenses/by-sa/4.0/legalcode
 *
*/

//
//  ViewController.m
//  ONLYOFFICE
//
//  Created by Alexander Yuzhin on 9/7/15.
//  Copyright (c) 2015 Ascensio System SIA. All rights reserved.
//

#import "ViewController.h"
#import "mac_application.h"
#import "ASCTabsControl.h"
#import "ASCTabView.h"
#import "ASCTitleWindowController.h"
#import "ASCHelper.h"
#import "ASCConstants.h"
#import "ASCUserInfoViewController.h"
#import "NSView+ASCView.h"
#import "NSString+OnlyOffice.h"
#import "AppDelegate.h"
#import "NSCefView.h"
#import "ASCEventsController.h"

#define rootTabId @"1CEF624D-9FF3-432B-9967-61361B5BFE8B"

@interface ViewController() <ASCTabsControlDelegate, ASCTitleBarControllerDelegate, ASCUserInfoViewControllerDelegate>
@property (weak) ASCTabsControl *tabsControl;
@property (weak) IBOutlet NSTabView *tabView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onWindowLoaded:)
                                                 name:ASCEventNameMainWindowLoaded
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCEFCreateTab:)
                                                 name:CEFEventNameCreateTab
                                               object:nil];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    // Update the view, if already loaded.
}


- (void)onWindowLoaded:(NSNotification *)notification {
    if (notification && notification.object) {
        ASCTitleWindowController *windowController = (ASCTitleWindowController *)notification.object;
        windowController.titlebarController.delegate = self;
        
        self.tabsControl = windowController.titlebarController.tabsControl;
        
        [self setupTabControl];
        [self loadStartPage];
        
        // Create CEF event listener
        [ASCEventsController sharedInstance];
    }
}

- (void)setupTabControl {
    self.tabsControl.minTabWidth = 48;
    self.tabsControl.maxTabWidth = 135;
    
    [self.tabsControl.multicastDelegate addDelegate:self];
}

- (void)loadStartPage {
    NSInteger rootTabIndex = [self.tabView indexOfTabViewItemWithIdentifier:rootTabId];
    
    if (rootTabIndex != NSNotFound) {
        NSTabViewItem * tab = [self.tabView tabViewItemAtIndex:rootTabIndex];
        
        CAscApplicationManager * appManager = [((NSAscApplication *)[NSApplication sharedApplication]) getAppManager];
        NSUserDefaults * preferences = [NSUserDefaults standardUserDefaults];
        
        NSURLComponents *loginPage      = [NSURLComponents componentsWithString:[[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:@"login"]];
        NSURLQueryItem *countryCode     = [NSURLQueryItem queryItemWithName:@"lang" value:[[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode] lowercaseString]];
        NSURLQueryItem *portalAddress   = [NSURLQueryItem queryItemWithName:@"portal" value:[preferences objectForKey:ASCUserSettingsNamePortalUrl]];
        loginPage.queryItems            = @[countryCode, portalAddress];
        loginPage.scheme                = NSURLFileScheme;
        
        NSCefView * cefView = [[NSCefView alloc] initWithFrame:tab.view.frame];
        [cefView Create:appManager withType:cvwtSimple];
        [cefView Load:[loginPage string]];
        [tab.view addSubview:cefView];
        [cefView setupFillConstraints];
    }
}

#pragma mark -
#pragma mark - CEF events handlers

- (void)onCEFCreateTab:(NSNotification *)notification {
    if (notification && notification.userInfo) {
        NSDictionary * params = (NSDictionary *)notification.userInfo;
        
        ASCTabView *tab = [[ASCTabView alloc] initWithFrame:CGRectZero];
        tab.title       = NSLocalizedString(@"Document", nil);
        tab.type        = ASCTabViewOpeningType;
        tab.url         = params[@"url"];

        [self.tabsControl addTab:tab selected:[params[@"active"] boolValue]];
    }
}

#pragma mark -
#pragma mark - ASCTabsControl Delegate

- (void)tabs:(ASCTabsControl *)control didSelectTab:(ASCTabView *)tab {
    if (tab) {
        [self.tabView selectTabViewItemWithIdentifier:tab.uuid];
    }
}

- (void)tabs:(ASCTabsControl *)control didAddTab:(ASCTabView *)tab {
    CAscApplicationManager * appManager = [((NSAscApplication *)[NSApplication sharedApplication]) getAppManager];
    NSCefView * cefView = [[NSCefView alloc] initWithFrame:CGRectZero];
    [cefView Create:appManager withType:cvwtEditor];
    [cefView Load:tab.url];
    
    tab.uuid = [NSString stringWithFormat:@"%ld", (long)cefView.uuid];
    
    NSTabViewItem * item = [[NSTabViewItem alloc] initWithIdentifier:tab.uuid];
    item.label = tab.title;
    [self.tabView addTabViewItem:item];
    [item.view addSubview:cefView];
    [cefView setupFillConstraints];
}

- (BOOL)tabs:(ASCTabsControl *)control willRemovedTab:(ASCTabView *)tab {
//    if ((rand() % 10) % 2) {
//        NSAlert *alert = [[NSAlert alloc] init];
//        [alert addButtonWithTitle:@"OK"];
//        [alert addButtonWithTitle:@"Cancel"];
//        [alert setMessageText:@"Delete the record?"];
//        [alert setInformativeText:@"Deleted records cannot be restored."];
//        [alert setAlertStyle:NSWarningAlertStyle];
//        
//        [alert beginSheetModalForWindow:[NSApp mainWindow] completionHandler:^(NSModalResponse returnCode) {
//            if(returnCode == NSAlertFirstButtonReturn) {
//                [control removeTab:tab];
//            }
//        }];
//
//        return NO;
//    }
    return YES;
}

- (void)tabs:(ASCTabsControl *)control didRemovedTab:(ASCTabView *)tab {
    [self.tabView removeTabViewItem:[self.tabView tabViewItemAtIndex:[self.tabView indexOfTabViewItemWithIdentifier:tab.uuid]]];
}

- (void)tabs:(ASCTabsControl *)control didReorderTab:(ASCTabView *)tab {
    //
}

#pragma mark -
#pragma mark - ASCTitleBarController Delegate

- (void)onOnlyofficeButton:(id)sender {
    [self.tabView selectTabViewItemWithIdentifier:rootTabId];
    [self.tabsControl selectTab:nil];
}

- (void)onShowUserInfoController:(NSViewController *)controller {
    ASCUserInfoViewController *userInfoController = (ASCUserInfoViewController *)controller;
    userInfoController.delegate = self;
}

#pragma mark -
#pragma mark - ASCUserInfoViewController Delegate

- (void)onLogoutButton:(ASCUserInfoViewController *)controller {
    NSLog(@"on logout");
}

#pragma mark -
#pragma mark - Debug

//- (IBAction)onAddTab:(id)sender {
//    ASCTabView *tab = [[ASCTabView alloc] initWithFrame:CGRectZero];
//    tab.title = [NSString stringWithFormat:@"Tab %lu", (unsigned long)rand() % 10000];
//    [self.tabsControl addTab:tab];
//}
//
//- (IBAction)onRemoveTab:(id)sender {
//    [self.tabsControl removeTab:[[self.tabsControl tabs] firstObject]];
//}
@end
//
//  PreferencesTabViewController.swift
//  Prephirences
/*
The MIT License (MIT)

Copyright (c) 2015 Eric Marchand (phimage)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

import Cocoa

/* Controller of tab view item can give prefered size by implementing this protocol */
@objc public protocol PreferencesTabViewItemControllerType {
    
    var preferencesTabViewSize: NSSize {get}
}
/* Key for event on property preferencesTabViewSize */
public let kPreferencesTabViewSize = "preferencesTabViewSize"

/* Controller which resize parent window according to tab view items, useful for preferences */
public class PreferencesTabViewController: NSTabViewController {
    
    // Keep size of subview
    private var cacheSize = [NSView: NSSize]()
    
    // MARK: overrides

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.transitionOptions = NSViewControllerTransitionOptions.None
    }

    override public func tabView(tabView: NSTabView, willSelectTabViewItem tabViewItem: NSTabViewItem) {
        // remove listener on previous selected tab view
        if let selectedTabViewItem = self.selectedTabViewItem as? NSTabViewItem,
            viewController = selectedTabViewItem.viewController as? PreferencesTabViewItemControllerType {
                (viewController as! NSViewController).removeObserver(self, forKeyPath: kPreferencesTabViewSize, context: nil)
        }
        
        super.tabView(tabView, willSelectTabViewItem: tabViewItem)

        // get size and listen to change on futur selected tab view item
        if let view = tabViewItem.view {
            let currentSize = view.frame.size // Expect size from storyboard constraints or previous size

            if let viewController = tabViewItem.viewController as? PreferencesTabViewItemControllerType {
                cacheSize[view] = getPreferencesTabViewSize(viewController, currentSize)
 
                // Observe kPreferencesTabViewSize
                let options = NSKeyValueObservingOptions.New | NSKeyValueObservingOptions.Old
                (viewController as! NSViewController).addObserver(self, forKeyPath: kPreferencesTabViewSize, options: options, context: nil)
            }
            else {
               cacheSize[view] = cacheSize[view] ?? currentSize
            }
        }
    }

    override public func tabView(tabView: NSTabView, didSelectTabViewItem tabViewItem: NSTabViewItem) {
        super.tabView(tabView, didSelectTabViewItem: tabViewItem)
        if let view = tabViewItem.view, window = self.view.window, contentSize = cacheSize[view] {
            self.setFrameSize(contentSize, forWindow: window)
        }
    }

    public override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if keyPath == kPreferencesTabViewSize {
            if let window = self.view.window, viewController = object as? PreferencesTabViewItemControllerType,
                view = (viewController as? NSViewController)?.view, currentSize = cacheSize[view]  {
                    let contentSize = self.getPreferencesTabViewSize(viewController, currentSize)
                    cacheSize[view] = contentSize
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        self.setFrameSize(contentSize, forWindow: window)
                    }
            }
        }
        else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    override public func removeTabViewItem(tabViewItem: NSTabViewItem) {
        if let view = tabViewItem.view {
            if let viewController = tabViewItem.viewController as? PreferencesTabViewItemControllerType {
                tabViewItem.removeObserver(viewController as! NSViewController, forKeyPath: kPreferencesTabViewSize)
            }
        }
    }

    func _removeAllToolbarItems(){
        // Maybe fix a bug with toolbar style
    }
    
    // MARK: public

    public var selectedTabViewItem: AnyObject? {
        return selectedTabViewItemIndex<0 ? nil : tabViewItems[selectedTabViewItemIndex]
    }

    // MARK: privates

    private func getPreferencesTabViewSize(viewController: PreferencesTabViewItemControllerType, _ referenceSize: NSSize) -> NSSize {
        var controllerProposedSize = viewController.preferencesTabViewSize
        if controllerProposedSize.width <= 0 { // 0 means keep size
            controllerProposedSize.width = referenceSize.width
        }
        if controllerProposedSize.height <= 0 {
            controllerProposedSize.height = referenceSize.height
        }
        return controllerProposedSize
    }
    
    private func setFrameSize(size: NSSize, forWindow window: NSWindow) {
        let newWindowSize = window.frameRectForContentRect(NSRect(origin: CGPointZero, size: size)).size
        
        var frame = window.frame
        frame.origin.y += frame.size.height
        frame.origin.y -= newWindowSize.height
        frame.size = newWindowSize
        
        window.setFrame(frame, display:true, animate:true)
    }

}
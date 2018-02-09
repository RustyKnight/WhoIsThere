#rm -rf ~/Library/Caches/org.carthage.CarthageKit/dependencies/
#sudo xcode-select -s /Applications/Xcode-beta.app/Contents/Developer
xcodebuild -version
time carthage update --platform iOS --configuration Debug
rm -rf Carthage/Build/iOS/Cioffi_Core.framework/Frameworks
#sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

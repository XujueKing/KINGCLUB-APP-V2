"""Apply a bounded iOS 26 cropper control workaround after flutter pub get."""

import json
from pathlib import Path
from urllib.parse import unquote, urljoin, urlparse


MARKER = "// KINGCLUB iOS 26 crop controls"
ANCHOR = '''  if (cancelButtonTitle && [cancelButtonTitle isKindOfClass:[NSString class]]) {
    controller.cancelButtonTitle = cancelButtonTitle;
  }
}'''
PATCH = '''
  // KINGCLUB iOS 26 crop controls
  // Keep this independent of TOCropToolbar's SDK-gated text/glass buttons.
  if (@available(iOS 26.0, *)) {
    controller.cancelButtonHidden = YES;
    controller.doneButtonHidden = YES;
    __weak TOCropViewController *weakController = controller;
    UIButton *back = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButton *confirm = [UIButton buttonWithType:UIButtonTypeSystem];
    [back setTitle:cancelButtonTitle forState:UIControlStateNormal];
    [confirm setTitle:doneButtonTitle forState:UIControlStateNormal];
    UIColor *gold = [UIColor colorWithRed:201.0/255 green:182.0/255 blue:158.0/255 alpha:1];
    for (UIButton *button in @[back, confirm]) {
      button.translatesAutoresizingMaskIntoConstraints = NO;
      button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
      [button setTitleColor:gold forState:UIControlStateNormal];
      [controller.view addSubview:button];
    }
    back.accessibilityLabel = cancelButtonTitle;
    confirm.accessibilityLabel = doneButtonTitle;
    [back addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
      TOCropViewController *cropper = weakController;
      if (cropper.toolbar.cancelButtonTapped) cropper.toolbar.cancelButtonTapped();
    }] forControlEvents:UIControlEventTouchUpInside];
    __weak UIButton *weakConfirm = confirm;
    [confirm addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
      weakConfirm.enabled = NO;
      [weakController commitCurrentCrop];
    }] forControlEvents:UIControlEventTouchUpInside];
    UILayoutGuide *safe = controller.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
      [back.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
      [confirm.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
      [back.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
      [confirm.topAnchor constraintEqualToAnchor:back.topAnchor],
      [back.widthAnchor constraintEqualToConstant:64],
      [confirm.widthAnchor constraintEqualToConstant:64],
      [back.heightAnchor constraintEqualToConstant:44],
      [confirm.heightAnchor constraintEqualToConstant:44]
    ]];
  }
'''


def patch_source(source: str) -> str:
    if MARKER in source:
        if source.count(MARKER) != 1 or PATCH not in source:
            raise ValueError("Unexpected partial cropper patch; inspect before building")
        return source
    if source.count(ANCHOR) != 1:
        raise ValueError("Cropper source changed; review workaround before building")
    return source.replace(ANCHOR, ANCHOR[:-1] + PATCH + "}", 1)


def apply(config_path: Path) -> None:
    config = json.loads(config_path.read_text(encoding="utf-8"))
    entry = next(p for p in config["packages"] if p["name"] == "image_cropper")
    uri = urlparse(urljoin(config_path.resolve().as_uri(), entry["rootUri"]))
    if uri.scheme != "file":
        raise ValueError("Expected a local resolved image_cropper package")
    path = unquote(uri.path)
    if len(path) > 2 and path[0] == "/" and path[2] == ":":
        path = path[1:]
    root = Path(path)
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    if "version: 12.2.1" not in pubspec.splitlines():
        raise ValueError("Review cropper workaround for the new dependency version")
    target = root / "ios/image_cropper/Sources/image_cropper/FLTImageCropperPlugin.m"
    original = target.read_text(encoding="utf-8")
    updated = patch_source(original)
    if updated != original:
        target.write_text(updated, encoding="utf-8")
    print("iOS avatar cropper controls patch verified")


if __name__ == "__main__":
    apply(Path(__file__).resolve().parents[1] / ".dart_tool/package_config.json")

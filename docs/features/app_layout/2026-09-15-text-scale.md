# A/B phone text adaptation

User requested consistent native UI after phone B displayed oversized text. Actual A: 1080x2400 at density 480, system font scale 1.0 (360 logical width). B: 720x1604, density overridden from 320 to 360, font scale 1.35 (320 logical width). System settings remain untouched.

Apply a shared MediaQuery text-scaling bound at MaterialApp's builder so pages, inputs and overlays share the policy. Base compact-screen factor on logical shortest dimension / 360, bounded 0.9–1.0; retain system text scaling within 0.85–1.1 times that factor. A at default settings is unchanged; B's combined enlarged display/font settings produce at most 0.99 text scale rather than 1.35. Existing responsive geometry, icons and approved colors/layout remain intact. This intentionally limits large system text in this app per the user's consistency request; a separate app text-size preference is not implemented.

Verify inherited scaling in text/input widgets at both actual logical widths, including narrow layouts. Device installation and user visual acceptance must be recorded separately from widget tests.

Validation: widget test uses actual A/B logical view sizes and system font scales, confirms unchanged A scaling and shared 0.99 maximum for B title/input, with no test layout exception. Targeted analysis passed. Device visual acceptance is pending the new installation.

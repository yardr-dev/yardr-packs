# Third-party notices

The webdesign pack draws on two projects. Both are in `roles/designer.md`, the
only file of the pack that holds them. This file keeps what each licence asks of
a copy, with the licence text as it stands at the pinned commit. `webdesign/test`
checks that the vendored block in the role and both texts below are the bytes
recorded here.

## frontend-design

- Project: the `frontend-design` skill in Anthropic's skills repository.
- Source: https://github.com/anthropics/skills/tree/ca45fc496a3436251f191354091d557da31c15b5/skills/frontend-design
- Pin: `anthropics/skills@ca45fc4`, full commit `ca45fc496a3436251f191354091d557da31c15b5`, committed 28 October 2026.
- Licence: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0). The text is the skill's own `LICENSE.txt` at the pin, below.
- Copyright line: none. `LICENSE.txt` and `SKILL.md` at the pin name no copyright holder, and the repository root holds no `LICENSE` or `NOTICE` file. The skill is published by Anthropic, and the repository's README says many of its skills are open source under Apache 2.0.
- Taken: the body of `SKILL.md`, whole, from its heading `# Frontend Design` to its last line (65 lines, 9,102 bytes). `roles/designer.md` carries it between two marker comments, under a one-line notice of its source.
- Changed: the frontmatter of `SKILL.md` (name, description, and `license: Complete terms in LICENSE.txt`) is left out. The body is unmodified. The notice at the head of the block says so, which is what section 4(b) of the licence asks of a modified file.
- Recorded bytes: the vendored body is sha256 `9a431b51da4772b46331b8b630da283bad07b87c7569f16a54f3e0e16f8784d2`. At the pin, `SKILL.md` is 9,390 bytes with sha256 `d91970639e9f5c37682ac7ab60094d35f1c7c1f38d731bd56396563aee10c1d3`, and `LICENSE.txt` is 10,174 bytes with sha256 `0d542e0c8804e39aa7f37eb00da5a762149dc682d7829451287e11b938e94594`.

The licence text, as at the pin:

<!-- begin licence: frontend-design -->
```text

                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS
```
<!-- end licence: frontend-design -->

## taste-skill

- Project: taste-skill (`design-taste-frontend`, "tasteskill v2") by Leonxlnx.
- Source: https://github.com/Leonxlnx/taste-skill/tree/12af471f627f866411b4bd785b19646d3672784c
- Pin: `Leonxlnx/taste-skill@12af471`, full commit `12af471f627f866411b4bd785b19646d3672784c`, committed 24 October 2026.
- Licence: MIT. The text is the repository's `LICENSE` at the pin, below.
- Copyright line: Copyright (c) 2026 Leonxlnx
- Taken: the method of `skills/taste-skill/SKILL.md`, in this pack's own words: choosing three directions that differ and one idea for each, a house style that keeps stock devices out of a page, and the look-and-fix round on screenshots. It is in steps 2 and 4 and the house style section of `roles/designer.md`, under a one-line notice of its source.
- Also taken, from the skill's "Page or app screen" section and from `skills/taste-skill/references/app-screens.md`, in this pack's own words: the rules for a screen people work in. They are to tell it from a page first, to let the biggest block answer one question, to keep panels quiet, to align figures, to spend colour on data, to use believable data, and to fold the navigation away on a phone. They are in the app screens section of `roles/designer.md`, under a one-line notice of their source.
- Not in this pack: the skill's library, its other references and its scripts, and the stylesheet and chart script that the app-screens reference builds on (`skills/taste-skill/assets/app.css` and `skills/taste-skill/assets/charts.js`), with its inspector (`skills/taste-skill/scripts/inspect.mjs`).
- Changed: reworded and condensed, and bent to the pack's purpose. A device the skill bans outright stays allowed when a direction chooses it, so that three directions keep their range. Of the app-screens reference the pack keeps a handful of its rules, and none of its study of real screens, its tables or its library of styles.
- Recorded bytes: at the pin, `skills/taste-skill/SKILL.md` is 39,537 bytes with sha256 `3435ed963b15a1b6447746ec8844ab2cd38d8d2e8ead3451937f42df01e408c4`, `skills/taste-skill/references/app-screens.md` is 85,358 bytes with sha256 `55e937ec30de605b53a11310b446f328a3ce7403de24fff008920a00be1a5ed4`, and `LICENSE` is 1,065 bytes with sha256 `4575a543ab88dad12ccea7d97e563d0bce5b448b06072e65d3264497dad326df`.

The method and the rules are reworded, not copied. MIT asks that its copyright and permission notice go with copies and substantial portions of the work, and this file keeps both with the pack regardless.

The licence text, as at the pin:

<!-- begin licence: taste-skill -->
```text
MIT License

Copyright (c) 2026 Leonxlnx

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
```
<!-- end licence: taste-skill -->

# Article draft — v0.2 (2026-08-12)

*Square brackets mark facts to fill in or confirm. Written venue-agnostic; trimming notes per venue are at the end. Figures listed after the body.*

*v0.2: the story is complete — the three-run arc (half the class → half the class → **every group**) replaces the "version two in progress" ending; send-flow described as shipped; privacy-by-practice (team names) added; figure plan + venue notes updated. v0.1 was written after run 1 (2026-07-16).*

---

## Working titles (pick one)

1. **Mapping the Air We Breathe: A Phone-Based Air-Quality Field Lab**
2. From Handheld Sensor to Class Map: An Air-Quality Field Activity with Nothing to Install
3. Twenty-Five Dots on a Map: Teaching Measurement, Uncertainty, and Air Quality with Students' Own Phones
4. Getting Every Group on the Map: Three Iterations of a Phone-Based Air-Quality Field Lab

**Standfirst:** In one afternoon, visiting high-school students turn a university campus into a live air-quality dataset — using handheld sensors, the phones already in their pockets, and a pair of open-source tools that assemble everyone's measurements into a single interactive map for the debrief.

---

## Draft

On a July afternoon, small groups of high-school students fan out across the University of Toronto Scarborough (UTSC) campus. Each group carries a handheld air-quality monitor in one hand and a phone in the other. They pause at a loading dock, inside the food court, under the trees in the campus valley; they watch the monitor's numbers flicker, argue briefly about what "typical" means, and type a reading into a web app that quietly stamps it with GPS coordinates and the time. Ninety minutes later they are back in the lecture hall, and the whole afternoon condenses onto one projected map: every group's measurements, colour-coded by pollutant, assembled while they watched.

This is the field component of Air Quality Science Day, a [one-day outreach event / program name] we run at UTSC for visiting high-school students [~N students in M groups — fill in]. The morning is a lecture on atmospheric structure, pollution sources, and how air quality is measured and modelled. The afternoon hands the students the instruments. This article describes the activity, the free and open-source software we built to run it, and what three class runs taught us — including a data-collection failure that took two software versions and one change of classroom protocol to close.

### Why air quality

Air quality is a rare topic that is simultaneously personal, local, physical, and global. Students have breathed wildfire smoke — one of our three 2026 runs, described below, measured straight through a Toronto smoke peak; they have seen an Air Quality Index number on a weather app without knowing what goes into it. And the underlying science runs from combustion chemistry through aerosol physics to the data-assimilation problems of global climate records. An afternoon of measurement can touch all of it.

The instrument we use, a consumer-grade handheld monitor ([Temtop M2000+, roughly $150–300 — confirm price]), reads PM2.5, PM10, particle count, CO₂, formaldehyde (HCHO), temperature, and humidity. Any similar monitor would work — a point worth emphasizing, because the software described below is deliberately sensor-agnostic: students read values off *any* device's screen and type them in. There is no Bluetooth pairing, no vendor lock-in, and nothing to break.

Before groups leave the room, they commit to predictions: Where on campus will particulate matter be highest? Where will CO₂ be highest? What counts as the "best" and "worst" air on campus — and who gets to define *best*? The definitional question is deliberately left open. Some groups optimize for low PM2.5, others for low CO₂, others for comfort; the debrief surfaces the disagreement, which is exactly the conversation public AQI standards have internally all the time.

In the field, the protocol asks for more than a number. Students watch the display for a couple of minutes at each site and record a typical value *and* its variability — the app's entry form literally reads "425 ± 15 ppm". Short-term fluctuation, instrument noise, a bus pulling away mid-measurement: uncertainty stops being a lecture concept and becomes a thing you have to decide how to write down. Each reading is tagged indoor or outdoor, and free-text notes capture context ("beside idling truck", "AC vent above us").

### The app: nothing to install

The awkward truth of school technology is that the students' own phones are the best data-collection hardware in the building — and the worst deployment target. Our visitors bring a mix of iOS and Android devices, with no institutional device management and no appetite for app-store installs during a one-day event.

So the data-entry app, **AQ Mapper**, is a web app. Students scan a QR code on a printed handout, the app opens in the browser, and "Add to Home Screen" makes it feel native. Underneath it is a single Flutter codebase that also builds real iOS and Android apps, but the web build is the distribution path: no accounts, no store, no version skew across the room.

Three design decisions carry the pedagogy:

- **Offline-first.** Readings live in an on-device database, and the campus map tiles are pre-bundled with the app, so the map works in the field without wifi. GPS, of course, needs no connection at all.
- **Uncertainty is a first-class field.** Every variable is entered as mean ± variability, mirroring the paper observation sheet. Sanity bounds catch impossible entries ("hard" limits block; "soft" limits ask *are you sure?* — a gentle introduction to quality control).
- **Privacy by design — and by practice.** The app collects no names and requires no sign-in. Measurements are tagged with a group label and a sensor ID, nothing else. We brief groups to pick a team name rather than their own names — a briefing that hardened into protocol across the runs: early groups sometimes typed given names, while by the final run the labels ran to "Rain", "Amazing", and "bangbangaptapt10086". A pseudonymization pass over group labels therefore precedes any release of the raw data. For an activity involving minors, this mattered as much as any feature.

Students see their own map immediately: points colour-coded by any variable, with legend thresholds tied to health guidance, and a heatmap toggle. That instant feedback loop — measure, see your dot appear, decide where to go next — turns sampling strategy into a live decision rather than a worksheet afterthought.

### Home base: the class map

The payoff is the debrief. Each group's data reaches the instructor — since version three by a one-tap **Send to class** upload, with CSV export by email or AirDrop kept as the fallback (the story of that evolution is below) — and a small Python/Plotly tool on the instructor's laptop (we call it **home base**) merges everything, removes duplicates, and renders interactive maps that are projected to the class.

The reveal has a choreography. First one group's map: "Here's Group 24's afternoon." Then the merge: the full class dataset — 128 measurements in our final run, gathered by groups that ranged as much as 1.4 km across campus in their 90 minutes. The dropdowns switch pollutants and filter indoor versus outdoor, and the room reliably supplies the narrative before I do: indoor CO₂ towers over outdoor (a ventilation tracer, not an outdoor pollutant), PM2.5 clusters near [roads / loading docks / construction — use your actual highlight], and someone always asks about the outlier, which is where the best conversations start. In our final run the outlier was deliberate: one group held the sensor beside a lit cigarette and logged 768 µg/m³ — ten times that summer's wildfire-day median — an unprompted point-source experiment I later replicated at roughly 200 µg/m³ near another smoker. That one dot did more for the ambient-versus-plume distinction than any slide could. A summary panel shows indoor-vs-outdoor averages and a per-group table, so every group can find itself in the data.

Two display choices earn their keep pedagogically. Colour scales come in two modes: **health bands** (absolute, matching the app's legend — most of campus, most days, is reassuringly green) and **spread** (rescaled to the day's data range — suddenly structure appears *within* the green). The switch itself is the lesson: the same data can look uniform or dramatic depending on the colour scale, which is a media-literacy vaccine for every heat map the students will ever see in the news.

Running the activity three times added an axis we had not planned: **between days**. Our very first run (15 July 2026) coincided with a wildfire-smoke peak over Toronto: the outdoor PM2.5 median was 79 µg/m³, with 97% of outdoor readings above 50, and we issued N95 masks (3M 1870+ Aura) for the outdoor legs — a live demonstration that the thresholds colouring the map are the thresholds that govern action. On the absolute health-band scale, the same campus that renders green on a clear day (outdoor medians of 2 and 11 µg/m³ on our other runs) rendered solidly red through the smoke. The indoor readings carried their own lesson twice over: indoor air sat at well under half the outdoor level (median 32 versus 79 µg/m³ — buildings as shelter), yet far above the 1–3 µg/m³ of clean-day indoor air (the smoke follows you inside, attenuated but not stopped). CO₂, meanwhile, told the same story on all three days — indoor medians near 700 ppm against outdoor near 480 — a tidy contrast between a signal governed by ventilation and one governed by the day's atmosphere. Two class maps side by side — smoke day and clear day, one colour scale — connect a continental-scale event to the students' own afternoon in a way no downloaded AQI chart can.

The second is an **interpolated field**: a smooth estimated surface between the sample points, fading out where no one sampled, with the real measurements overlaid as dots. A dropdown widens the smoothing radius — tight, then wide — and the estimated coverage grows while the honesty of the estimate shrinks. This is, in miniature, the choice NASA's GISTEMP global temperature analysis makes with its 250 km versus 1200 km smoothing radius, and we show the students that parallel directly. Their 128 points over a campus become a doorway into how the Arctic gets a temperature on a map few thermometers have ever touched. "If you were designing a monitoring network for a city, where would you put the sensors?" lands differently after you have watched your own data run out of coverage.

### What three runs taught us

The first full run (July 2026, [cohort size]) worked: groups measured, the maps built, the discussion carried itself. GPS delivered a bonus lesson when [one phone with imprecise location settings placed its readings ~1.4 km off campus — confirm/replace with your example]: a visible, discussable data-quality failure, exactly the kind reference networks screen for.

The honest failure was logistics: exporting a CSV and emailing it proved harder than measuring air. Between browser download quirks and attachment fumbles, **just over half the groups' files reached me** during the session. The lab survived — the maps were compelling with the data we had — but "where's the rest of the class?" is not a question you want a map to raise. The sting had an extra edge that day: run one was the wildfire-smoke afternoon described above — the most scientifically dramatic dataset of the season, and half of it never arrived.

Our first fix was better plumbing on the same pipe: a dedicated send button invoking the phone's share sheet, a separate save-a-copy button, the instructor's address one tap from the clipboard. The second run promptly returned the same fraction — and revealed why. The obstacles were not interface friction but **assumptions about students' digital lives**: several groups had no email account to send *from*, and others had scanned the QR code with WeChat — the default reflex for our visiting cohort — leaving the app inside WeChat's built-in browser, which can neither share nor save files and keeps its own storage sandbox. Their data was collected, and stranded.

Version three removed the file from the transport entirely. A one-tap **Send to class** button posts every reading to a small collection endpoint — a free Google Apps Script feeding a spreadsheet, five minutes to deploy on any instructor's account — and re-sending is always safe because rows deduplicate by ID. A bilingual overlay now intercepts WeChat's browser and walks students to "Open in Browser / 在浏览器打开" before they begin. The share-sheet and CSV paths stayed as fallbacks: new capabilities joined the old ones rather than replacing them. The endpoint itself is deliberately ephemeral — created for the event and archived after it, so the necessarily public upload URL is secured by its *lifetime* rather than by secrecy.

Just as deliberately, the third run changed the classroom protocol alongside the software. Groups picked up the one-page reference sheet at the door, signed out instruments, and were walked to a working state: sensor on the right screen, app configured — and then **every group took and submitted its first measurement together, in the room, with the receiving spreadsheet projected live**. Each group watched its own row arrive before anyone left the building. TAs circulated; no group walked out without a proven pipeline.

The result: **every group's data arrived.** Groups re-sent on their own throughout the afternoon — safe re-sending turned the projected sheet into a live progress tracker nobody had designed — and the fallbacks still earned their keep when two groups hit connectivity trouble in the field and delivered by email and by AirDrop to a TA on return. Quality control stayed human-scale: the one junk submission of the day (blank values, a location note) was caught by an instructor glancing at a 25-row spreadsheet. We changed the software and the protocol at once, so we cannot apportion the credit between them — the goal was a working lab, not a controlled experiment — but the shape of the lesson is clear, and it generalizes: the highest-risk component of a field campaign is rarely the sensor, and the fix for a data-return problem was half code, half choreography.

### What students practice

- **Measurement and uncertainty** — deciding what "the reading" is when the display won't sit still, and recording a defensible ± with it.
- **Sampling design** — choosing sites against a hypothesis, then confronting the coverage they didn't get.
- **Instrument literacy** — consumer sensors versus the reference instrument on our rooftop observatory [confirm you discussed AA-roof comparison]; cross-sensitivities (the HCHO channel responds to other VOCs); metadata that can invalidate a point (GPS accuracy).
- **Data-to-story literacy** — colour scales, interpolation, and the difference between what was measured and what a map claims.
- **Agency** — their dot, on the class map, feeding the discussion. Several groups photographed the projected map with their own points on it. [Confirm/replace anecdote.]

### Run it at your school

Everything is open source (MIT): the student app runs at a public URL from any phone browser, and the whole system is two pieces — the Flutter app and a few hundred lines of commented Python for home base — designed so an instructor can maintain them. Rebranding for another campus is a one-file edit (titles, coordinates, sensor IDs, and the optional upload endpoint); the one-tap upload needs only a free Google account and five minutes, and points of interest for the student map — TA stations, a stay-inside boundary — are drawn by clicking on geojson.io. The repository includes the printable student handout, the lab observation sheet, and a synthetic-data generator so you can rehearse the entire flow, including the projected debrief, with zero hardware. Any handheld monitor works; ours cost about [$X] each, and phones are the ones already in the room.

Repository: **github.com/DanWeaver-ca/aq-mapper** · Live app: **danweaver-ca.github.io/aq-mapper**

*[Acknowledgments: technician/colleague who field-tested; program that brings the visiting students; funding if any.]*

---

## Figure plan

1. **The loop** (composite): phone entry screen with ± field → student map with legend → projected class map. *(Default rule: regenerate all screenshots from `make_sample_data.py` output — publish nothing student-derived. **Skim result (2026-08-12):** all 48 distinct NOTES entries across the three runs are location/context descriptions — clean. But several run-1/run-2 group labels are real given names, so any data release or real-data figure requires a **group-label pseudonymization pass** first (trivial: rename the handful of name-labels; keep the whimsical ones). With that pass, real-data figures + a Zenodo-DOI'd dataset supplement are viable.)*
2. **Health bands vs spread** side-by-side of the same PM2.5 data — the colour-scale lesson in one image.
3. **Interpolated field, tight vs wide radius** side-by-side, with the GISTEMP parallel in the caption.
4. **Stats panel** (indoor vs outdoor CO₂ bars + per-group table).
5. *(Optional)* Photo of a group measuring in the field — requires consent/guardian release; the sample-data screenshots carry the piece if photos are unavailable.
6. *(Optional, CSL/JOSE more than TPT)* The bilingual WeChat interceptor overlay — regenerable with zero student data (`?simulate=wechat` in any browser); one image that tells the whole meet-students-where-they-are story.
7. **Smoke day vs clear day** — **draft version BUILT (2026-08-12)** by `docs/figures/make_fig_smoke_vs_clean.py` (script committed; the data stays local): two Home-Base-style panels — CARTO positron basemap with campus buildings and the valley forest, the app's band colours, shared health-band colourbar, 500 m scale bars — run 1 (15 July, smoke: outdoor median 79, panel renders red) beside run 3 (12 Aug, clear: median 11, renders green). Cigarette outlier annotated in-panel (confirmed real: a group's deliberate point-source experiment, 768 µg/m³; instructor replication ~200). Student-only data (DW-Test/TA rows excluded by convention). **Replaces** the sample-data version of figure 2. Remaining polish: neutral legend marker colours (they currently inherit each panel's data colours), decide on the half-clipped westernmost point, optional landmark labels. Group labels never appear in this figure, so the pseudonymization pass gates the *raw-data release*, not this figure.

---

## Venue notes (guidelines verified 2026-07-18 — re-check before formatting)

**Two tracks, two artifacts, pursued in parallel.** This draft is the *activity paper* for an education journal. The repository itself is separately publishable in **JOSE — the Journal of Open Source Education** (jose.theoj.org, JOSS's education sibling): diamond open access (no fees), and the peer review is of the repo itself against adoptability (feature-complete, documented, OSI-licensed) — requirements nearly identical to the pre-article polish round (CI, CITATION.cff, Zenodo DOI, quickstart), so that work serves both submissions. The two don't conflict (a different artifact is under review at each), and JOSE gives adopting colleagues a citable software DOI whatever education journals they do or don't read. Context for pushing the second track: a conference discussion relayed by [the summer-school TA — name] (2026-07) shows the atmospheric-science education community wants exactly this kind of app — see the outreach paragraph below.

| Venue | Audience & fit | Format notes | Angle to emphasize |
|---|---|---|---|
| **The Physics Teacher** (AAPT/AIP) — *first choice* | HS + intro-college physics teachers; long tradition of smartphone-sensor and low-cost-instrumentation activities | ≤3,000 words with each figure counted as 200 (draft + 4 figures ≈ 2,700 — fits if the optional photo figure is dropped); free via the subscription route; guidelines require searching past TPT issues for similar AQ activities and citing them | Measurement, uncertainty (±), instrument literacy; trim the outreach-program framing |
| **Connected Science Learning** (NSTA) — *second, if TPT declines* | Educators bridging in-school/out-of-school STEM — a university outreach day is squarely its territory | Rolling submissions; features 2,000–4,000 words + 200-word abstract; friendly to multimedia (screen recordings of the dashboard) | The outreach partnership, engagement, data literacy; tech details lighter |
| **Physics Education** (IOP) — *demoted to third (2026-07-18)* | International school/intro-university physics | Their current guidance "tends to discourage" full papers where smartphones merely replace standard equipment — this piece would likely be steered to a 1,000-word Frontline, too small for the story. Papers ≤3,000 words; free via subscription route (gold OA optional, £2,530) | Realistic only as a short Frontline pointing at the repo |
| **JOSE** (Journal of Open Source Education) — *parallel software track* | Educators who adopt open-source teaching software | Submits the *repo*, not this draft: short paper.md kept in-repo + open review on GitHub; no fees | The adoptable system: one-file rebrand (SETUP.md), zero-hardware rehearsal via sample data, tests/CI, privacy design |

**Recommendation (2026-07-18):** *The Physics Teacher* first for this draft, *Connected Science Learning* second, one education submission at a time; **JOSE in parallel** once the polish round lands. Archive the repo with a Zenodo DOI at submission time so both papers cite a frozen version.

**Update (2026-08-12, v0.2):** the story is complete — the arc now ends at *every group arrived* (run 3), which strengthens the TPT pitch (a resolved iteration story, not a work-in-progress). Costs ~300 words over v0.1; if TPT's budget pinches, trim first from "Why air quality" ¶1 and the standfirst, not from the three-run section — the arc *is* the article. Two framing disciplines for all venues: (1) claim that the WeChat *steering* worked (zero WeChat incidents in run 3 vs. many in run 2) — do **not** claim uploads from inside WeChat work; that path was never exercised. (2) The run-3 success confounds software and protocol *by design* — say so plainly; reviewers respect it, and "half code, half choreography" is the transferable finding. For the JOSE paper.md: carry over the secured-by-lifetime endpoint paragraph and the per-event deployment lifecycle (SETUP_UPLOAD.md "Closing up") — it is the reviewable answer to "how does an adopter run this safely?", and the privacy-by-practice team-name briefing belongs in the same section.

**Update (2026-08-12b, wildfire comparison):** one run coincided with a Toronto wildfire-smoke peak (PM2.5 > 50 µg/m³; N95 3M 1870+ Aura masks issued for outdoor legs). The between-days comparison paragraph + figure 7 are the piece's strongest real-world hook for every venue — TPT (thresholds→action; a safety protocol as pedagogy), CSL (lived event), even the BAMS/Eos angle (a synoptic event captured by a class). It raises the stakes of the real-data decision: the comparison figure is impossible with synthetic data. To confirm before figure work: which run was the smoke day; where the run-1/run-2 CSVs are retained; whether the indoor/outdoor PM2.5 inversion the draft hypothesizes actually appears in that run's data.

**Reaching the atmospheric-science community** (where the demand was voiced): none of the journals above reach them. Ask the TA which meeting/session the discussion happened in and match the outlet — *BAMS* publishes education/community-engagement articles (e.g. the 2025 NCAR field-campaign education paper, BAMS-D-24-0315.1), an *Eos* project update is lighter-weight, and a talk in an AGU/AMS/CMOS education session (which the TA could give) puts the live URL in front of the right room. All complementary to, not competing with, the activity paper.

**The JGE path (research paper, later):** *Journal of Geoscience Education* Curriculum & Instruction papers require grounding in the education literature plus **evidence the innovation meets its learning goals** — out of reach on the current experience-report evidence. The route there: the TA pilots AQ Mapper at their air-quality summer school (simultaneously a real test of the v1.2 one-file adoption story and a second deployment for the JOSE paper), collects even light learning-outcome data (REB approval needed), and co-authors.

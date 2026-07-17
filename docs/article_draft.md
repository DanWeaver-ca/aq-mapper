# Article draft — v0.1 (2026-07-16)

*Square brackets mark facts to fill in or confirm. Written venue-agnostic at ~1,900 words; trimming notes per venue are at the end. Figures listed after the body.*

---

## Working titles (pick one)

1. **Mapping the Air We Breathe: A Phone-Based Air-Quality Field Lab**
2. From Handheld Sensor to Class Map: An Air-Quality Field Activity with Nothing to Install
3. Twenty-Five Dots on a Map: Teaching Measurement, Uncertainty, and Air Quality with Students' Own Phones

**Standfirst:** In one afternoon, visiting high-school students turn a university campus into a live air-quality dataset — using handheld sensors, the phones already in their pockets, and a pair of open-source tools that assemble everyone's measurements into a single interactive map for the debrief.

---

## Draft

On a July afternoon, small groups of high-school students fan out across the University of Toronto Scarborough (UTSC) campus. Each group carries a handheld air-quality monitor in one hand and a phone in the other. They pause at a loading dock, inside the food court, under the trees in the campus valley; they watch the monitor's numbers flicker, argue briefly about what "typical" means, and type a reading into a web app that quietly stamps it with GPS coordinates and the time. Ninety minutes later they are back in the lecture hall, and the whole afternoon condenses onto one projected map: every group's measurements, colour-coded by pollutant, assembled while they watched.

This is the field component of Air Quality Science Day, a [one-day outreach event / program name] we run at UTSC for visiting high-school students [~N students in M groups — fill in]. The morning is a lecture on atmospheric structure, pollution sources, and how air quality is measured and modelled. The afternoon hands the students the instruments. This article describes the activity, the free and open-source software we built to run it, and what the first full class run taught us — including the failure that is shaping version two.

### Why air quality

Air quality is a rare topic that is simultaneously personal, local, physical, and global. Students have breathed wildfire smoke [adjust to your cohort's experience]; they have seen an Air Quality Index number on a weather app without knowing what goes into it. And the underlying science runs from combustion chemistry through aerosol physics to the data-assimilation problems of global climate records. An afternoon of measurement can touch all of it.

The instrument we use, a consumer-grade handheld monitor ([Temtop M2000+, roughly $150–300 — confirm price]), reads PM2.5, PM10, particle count, CO₂, formaldehyde (HCHO), temperature, and humidity. Any similar monitor would work — a point worth emphasizing, because the software described below is deliberately sensor-agnostic: students read values off *any* device's screen and type them in. There is no Bluetooth pairing, no vendor lock-in, and nothing to break.

Before groups leave the room, they commit to predictions: Where on campus will particulate matter be highest? Where will CO₂ be highest? What counts as the "best" and "worst" air on campus — and who gets to define *best*? The definitional question is deliberately left open. Some groups optimize for low PM2.5, others for low CO₂, others for comfort; the debrief surfaces the disagreement, which is exactly the conversation public AQI standards have internally all the time.

In the field, the protocol asks for more than a number. Students watch the display for a couple of minutes at each site and record a typical value *and* its variability — the app's entry form literally reads "425 ± 15 ppm". Short-term fluctuation, instrument noise, a bus pulling away mid-measurement: uncertainty stops being a lecture concept and becomes a thing you have to decide how to write down. Each reading is tagged indoor or outdoor, and free-text notes capture context ("beside idling truck", "AC vent above us").

### The app: nothing to install

The awkward truth of school technology is that the students' own phones are the best data-collection hardware in the building — and the worst deployment target. Our visitors bring a mix of iOS and Android devices, with no institutional device management and no appetite for app-store installs during a one-day event.

So the data-entry app, **AQ Mapper**, is a web app. Students scan a QR code on a printed handout, the app opens in the browser, and "Add to Home Screen" makes it feel native. Underneath it is a single Flutter codebase that also builds real iOS and Android apps, but the web build is the distribution path: no accounts, no store, no version skew across the room.

Three design decisions carry the pedagogy:

- **Offline-first.** Readings live in an on-device database, and the campus map tiles are pre-bundled with the app, so the map works in the field without wifi. GPS, of course, needs no connection at all.
- **Uncertainty is a first-class field.** Every variable is entered as mean ± variability, mirroring the paper observation sheet. Sanity bounds catch impossible entries ("hard" limits block; "soft" limits ask *are you sure?* — a gentle introduction to quality control).
- **Privacy by design.** The app collects no names and requires no sign-in. Measurements are tagged with a group code and a sensor ID, nothing else. For an activity involving minors, this mattered as much as any feature.

Students see their own map immediately: points colour-coded by any variable, with legend thresholds tied to health guidance, and a heatmap toggle. That instant feedback loop — measure, see your dot appear, decide where to go next — turns sampling strategy into a live decision rather than a worksheet afterthought.

### Home base: the class map

The payoff is the debrief. Each group exports its data as a CSV file and sends it to the instructor; a small Python/Plotly tool on the instructor's laptop (we call it **home base**) merges every file, removes duplicates, and renders interactive maps that are projected to the class.

The reveal has a choreography. First one group's map: "Here's Group 24's afternoon." Then the merge: the full class dataset, [~250 — fill in] measurements wide. The dropdowns switch pollutants and filter indoor versus outdoor, and the room reliably supplies the narrative before I do: indoor CO₂ towers over outdoor (a ventilation tracer, not an outdoor pollutant), PM2.5 clusters near [roads / loading docks / construction — use your actual highlight], and someone always asks about the outlier, which is where the best conversations start. A summary panel shows indoor-vs-outdoor averages and a per-group table, so every group can find itself in the data.

Two display choices earn their keep pedagogically. Colour scales come in two modes: **health bands** (absolute, matching the app's legend — most of campus is reassuringly green) and **spread** (rescaled to the day's data range — suddenly structure appears *within* the green). The switch itself is the lesson: the same data can look uniform or dramatic depending on the colour scale, which is a media-literacy vaccine for every heat map the students will ever see in the news.

The second is an **interpolated field**: a smooth estimated surface between the sample points, fading out where no one sampled, with the real measurements overlaid as dots. A dropdown widens the smoothing radius — tight, then wide — and the estimated coverage grows while the honesty of the estimate shrinks. This is, in miniature, the choice NASA's GISTEMP global temperature analysis makes with its 250 km versus 1200 km smoothing radius, and we show the students that parallel directly. Their eleven [fill in] points over a campus become a doorway into how the Arctic gets a temperature on a map few thermometers have ever touched. "If you were designing a monitoring network for a city, where would you put the sensors?" lands differently after you have watched your own data run out of coverage.

### What the first run taught us

The first full run [date, cohort size] worked: groups measured, the maps built, the discussion carried itself. GPS delivered a bonus lesson when [one phone with imprecise location settings placed its readings ~1.4 km off campus — confirm/replace with your example]: a visible, discussable data-quality failure, exactly the kind reference networks screen for.

The honest failure was logistics: exporting a CSV and emailing it proved harder than measuring air. Between browser download quirks and attachment fumbles, **just over half the groups' files reached me** during the session. The lab survived — the maps were compelling with the data we had — but "where's the rest of the class?" is not a question you want a map to raise. Version two, in progress, replaces the export-and-email dance with a one-tap **Send to class** button (posting the data to a small collection endpoint, with the share-sheet and CSV export kept as fallbacks) and merges home base's several windows into a single dashboard with a live checklist of which groups have reported. The instrumentation lesson generalizes: the highest-risk component of a field campaign is rarely the sensor.

### What students practice

- **Measurement and uncertainty** — deciding what "the reading" is when the display won't sit still, and recording a defensible ± with it.
- **Sampling design** — choosing sites against a hypothesis, then confronting the coverage they didn't get.
- **Instrument literacy** — consumer sensors versus the reference instrument on our rooftop observatory [confirm you discussed AA-roof comparison]; cross-sensitivities (the HCHO channel responds to other VOCs); metadata that can invalidate a point (GPS accuracy).
- **Data-to-story literacy** — colour scales, interpolation, and the difference between what was measured and what a map claims.
- **Agency** — their dot, on the class map, feeding the discussion. Several groups photographed the projected map with their own points on it. [Confirm/replace anecdote.]

### Run it at your school

Everything is open source (MIT): the student app runs at a public URL from any phone browser, and the whole system is two pieces — the Flutter app and a few hundred lines of commented Python for home base — designed so an instructor can maintain them. Rebranding for another campus is a one-file edit (title + default map coordinates); the repository includes the printable student handout, the lab observation sheet, and a synthetic-data generator so you can rehearse the entire flow, including the projected debrief, with zero hardware. Any handheld monitor works; ours cost about [$X] each, and phones are the ones already in the room.

Repository: **github.com/DanWeaver-ca/aq-mapper** · Live app: **danweaver-ca.github.io/aq-mapper**

*[Acknowledgments: technician/colleague who field-tested; program that brings the visiting students; funding if any.]*

---

## Figure plan

1. **The loop** (composite): phone entry screen with ± field → student map with legend → projected class map. *(Regenerate all screenshots from `make_sample_data.py` output — publish nothing student-derived.)*
2. **Health bands vs spread** side-by-side of the same PM2.5 data — the colour-scale lesson in one image.
3. **Interpolated field, tight vs wide radius** side-by-side, with the GISTEMP parallel in the caption.
4. **Stats panel** (indoor vs outdoor CO₂ bars + per-group table).
5. *(Optional)* Photo of a group measuring in the field — requires consent/guardian release; the sample-data screenshots carry the piece if photos are unavailable.

---

## Venue notes (check current author guidelines before formatting)

| Venue | Audience & fit | Format notes | Angle to emphasize |
|---|---|---|---|
| **The Physics Teacher** (AAPT/AIP) | HS + intro-college physics teachers; long tradition of smartphone-sensor and low-cost-instrumentation activities | Papers typically ~2,500 words + figures; peer-reviewed, practitioner voice | Measurement, uncertainty (±), instrument literacy; trim the outreach-program framing |
| **Connected Science Learning** (NSTA) | Educators bridging in-school/out-of-school STEM — a university outreach day is squarely its territory | Feature articles; friendly to multimedia (screen recordings of the interactive map!) | The outreach partnership, engagement, data literacy; tech details lighter |
| **Physics Education** (IOP) | International school/intro-university physics; welcomes papers on new practical activities and ICT | More room for method detail (~2,000–4,000 words) | Full activity design + the open-source how-to; keep the GISTEMP section |

**Recommendation:** *The Physics Teacher* as first choice for reach among physics educators, with *Connected Science Learning* as the best topical fit if you'd rather frame it as outreach than as a physics lab, and *Physics Education* if the method detail won't fit TPT's length. One submission at a time (none allow simultaneous submission). Worth knowing: an **Eos** (AGU) short piece could later serve as a community-facing companion without conflicting, and if you ever collect learning-outcome data, the *Journal of Geoscience Education* becomes the research-paper home. Archive the repo with a Zenodo DOI at submission time so the article cites a frozen version.

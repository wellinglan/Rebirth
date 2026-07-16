# Growth UI MVP Manual Test

## Preconditions

- Use a Sprint 7B build with Flutter database `schemaVersion` 3.
- No FastAPI, Docker, login, or network connection is required.
- Growth reads local Today, Health, and Journal facts and never writes them.
- Run on Windows and, when available, a physical Android device.

## Data Semantics

1. Open Growth with a completely empty local database. Confirm the title,
   7/30-day selector, date range, and calm empty card appear without sample
   charts or invented values.
2. Add only Today data. Confirm Research, Learning, Mood, and Energy can render
   while Sleep, Exercise, and Journal show local empty states.
3. Add only Health data. Confirm Sleep and Exercise render without requiring a
   Today record.
4. Add only Journal content. Confirm the page leaves the complete-empty state
   and shows coverage while numeric summaries remain `暂无数据`.
5. Leave several dates unrecorded. Confirm line charts have gaps and exercise
   has no bars on those dates; missing values must not appear on the baseline.
6. Explicitly record Research, Learning, Sleep, or Exercise as 0. Confirm 0 is
   displayed as `0 分钟` and appears at the chart baseline.

## Period And Loading

1. Open Growth and confirm `近 7 天` is selected by default with seven dates.
2. Select `近 30 天`. Confirm a light progress indicator appears while the old
   data remains visible, then the range and charts atomically change to 30 days.
3. Switch 7 -> 30 -> 7 rapidly. Confirm the final page stays on the last selected
   period and no older response replaces it.
4. Simulate an initial local read error. Confirm `成长趋势暂时无法加载` and the
   retry button appear without SQL, database paths, or stack traces.
5. Restore local reads and press Retry. Confirm Growth loads normally.
6. Simulate a refresh error after successful data. Confirm old charts remain
   visible and a non-blocking refresh failure message appears.

## Charts And Journal

1. Confirm Research/Learning, Mood/Energy legends contain text and are also
   distinguishable by solid or dashed line styles.
2. Confirm Sleep is a separate line chart and Exercise is a bar chart.
3. In 30-day mode, confirm all dates contribute data but horizontal labels are
   sparse and do not overlap.
4. Verify Journal has visually distinct missing, recorded draft, and completed
   cells. Confirm each cell's tooltip or screen-reader output includes date and
   state.
5. Confirm the Journal footer displays recorded and completed counts out of 7
   or 30 days.
6. Confirm no streak, flame, reward, growth score, ranking, pass rate, red/green
   change arrow, or evaluative success/failure language appears.

## Responsive And Accessibility

1. Resize Windows to a narrow content area around 360px. Confirm the summary
   grid wraps, recovery charts stack, and the page has no horizontal overflow.
2. Test around 720px and 840px content widths, then a wider Windows window.
   Confirm summary cards adapt to three or four columns and charts remain
   readable.
3. Scroll to the final Journal card. Confirm bottom navigation does not cover
   the final content.
4. On Android portrait, repeat 7/30-day switching and scroll through every
   section. Confirm touch targets work and no RenderFlex overflow appears.
5. Enable a screen reader or semantics inspector. Confirm the period selection,
   summary labels and values, chart summaries, and Journal date states are
   announced meaningfully.

## Scope Confirmation

- A chart gap means unrecorded data; it does not mean 0.
- 0 is an explicitly recorded numeric value.
- Growth has no previous-period comparison.
- Growth has no AI explanation.
- Growth has no cloud synchronization.
- Growth has no derived snapshot cache.

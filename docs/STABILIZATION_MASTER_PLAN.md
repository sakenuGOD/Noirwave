# STABILIZATION MASTER PLAN

Ключевая формулировка: **regression lock before new visuals**.

Сейчас задача не "сделать еще апдейт", а остановить регрессии и довести продукт до цельного состояния.

Главная проблема:
ты каждый раз улучшаешь один кусок, но возвращаешь старые баги:
- снова два Search;
- снова странный лимит 100 tracks;
- search живет отдельно от плеера;
- музыка из Search не запускается;
- после поиска кнопки/навигация ломаются;
- Library не похожа на референс, вместо этого постоянно показываются Nirvana / Daft Punk;
- lyrics не кликаются и не seek-ают песню;
- player стал слишком темным, mint accent плохо читается;
- sidebar сбилась по цветам и композиции;
- playlists внизу sidebar выглядят недоделанно, с заглушками и Daft Punk;
- во время подзагрузки все равно вылезает мусор/placeholder/slop.

Нужно выполнить каждый пункт ниже и не закрывать задачу, пока regressions не проверены.

## 1. Loading states / подзагрузка

Во время загрузки не должен вылезать мусор:
- не показывать случайные Nirvana / Daft Punk / placeholder data;
- не показывать старые stale карточки как будто это реальные данные;
- сделать нормальные skeleton states;
- если данные еще грузятся, UI должен выглядеть чисто;
- если данных нет, показывать empty state, а не fake content;
- убрать AI-slop заглушки.

## 2. Лимит 100 tracks

Сейчас "100 tracks" выглядит странно и подозрительно.

Нужно:
- проверить откуда берется лимит;
- убрать hardcode;
- если API реально отдает максимум 100, честно описать это в docs;
- если есть pagination, догружать страницы;
- UI не должен врать числом треков.

## 3. Search должен быть единым

Снова появилось два Search. Это regression.

Нужно оставить один search flow:
- sidebar search и search page используют один state;
- нет второго независимого поиска;
- поиск не ломает навигацию;
- после поиска кнопки Play / Artist / Album / Back / Library продолжают работать;
- search results должны быть частью общей app navigation, а не отдельным изолированным экраном.

## 4. Playback из Search

Сейчас если музыка играла до поиска, она продолжает играть, но если запустить трек из Search — он не запускается.

Нужно:
- Search results должны использовать тот же player store / playback engine;
- Play из search запускает трек;
- current track обновляется;
- mini player обновляется;
- queue/context корректно меняется;
- повторное нажатие работает как play/pause;
- не создавать отдельный fake playback внутри search.

## 5. Search buttons / navigation bug

После поиска кнопки перестают вести куда надо.

Исправить:
- artist click -> artist page;
- album click -> album page;
- track click/play -> playback;
- back/navigation не ломается;
- кнопки не становятся dead после query update;
- проверить это вручную после нескольких поисков подряд.

## 6. Library как на референсе

Я просил Library сделать как на втором фото.

Не надо постоянно показывать Nirvana и Daft Punk.

Нужно сделать Library экран с паттерном как на референсе:
- "Мне нравится" / liked songs крупным блоком;
- список любимых треков в 2 колонки или адаптивно;
- "Мои плейлисты" ниже;
- карточки плейлистов с нормальными обложками;
- create playlist tile;
- реальные saved/liked/playlists данные;
- если данных нет — чистый empty state, не fake Nirvana/Daft Punk.

## 7. Lyrics interactivity

Lyrics сейчас просто текст, но не кликается.

Нужно:
- lyrics lines должны быть clickable;
- click по строке lyrics -> seek к timestamp этой строки;
- active line подсвечивается;
- lyrics scroll sync с playback time;
- если у lyrics нет timestamps, явно показать unsynced mode и не делать fake seek;
- не ломать Queue/Sound tabs.

## 8. Player redesign

Mini player нравился, но сейчас стал слишком темный.

Нужно:
- вернуть readable premium glass;
- mint accent должен читаться;
- кнопка play/pause должна быть видимой;
- controls не должны тонуть в черном;
- не делать грязный dark gradient;
- сохранить компактность и дорогой вид;
- проверить contrast.

## 9. Sidebar redesign / colors

Левая панель опять сбилась и мимо цветов.

Нужно:
- привести sidebar к общей палитре приложения;
- убрать случайные зеленые/серые состояния;
- active item сделать аккуратным glass/accent state;
- search в sidebar не должен конфликтовать с основным Search;
- layout не должен ломаться;
- sidebar должна выглядеть как native music app, а не debug panel.

## 10. Playlists block in sidebar

Блок playlists снизу сейчас недоделанный:
- постоянные заглушки;
- Daft Punk везде;
- непонятные иконки;
- слабая структура.

Нужно выбрать одно:

A) либо полностью убрать этот блок из sidebar, если он не готов;

B) либо переизобрести с нуля:
- реальные playlists;
- нормальные cover fallbacks;
- no fake Daft Punk;
- compact native list;
- clear hover/click;
- empty state;
- no placeholder garbage.

Не оставлять промежуточную недоделку.

## 11. Regression checklist

Перед финалом обязательно проверить:
- нет двух Search;
- search запускает музыку;
- after search navigation still works;
- lyrics lines clickable и seek работают;
- Library не показывает fake Nirvana/Daft Punk;
- sidebar не сломана;
- mini player не слишком темный;
- loading не показывает мусор;
- 100 tracks объяснено или исправлено;
- playlists block либо удален, либо полностью переделан.

## 12. Docs mandatory

Обновить:
- docs/CHANGELOG.md
- docs/IMPLEMENTATION_NOTES.md
- docs/BUGS_AND_REGRESSIONS.md
- docs/DESIGN_NOTES.md

Отдельно записать:
- какие regressions были найдены;
- какие исправлены;
- какие файлы тронуты;
- как проверял search/playback/library/lyrics/sidebar/player;
- почему больше не должно вернуться два Search;
- откуда берется лимит 100 tracks.

## 13. Не мухлевать

Не делать вид, что задача выполнена, если:
- search все еще отдельный;
- play из search не работает;
- lyrics не seek-ают;
- fake data все еще появляется;
- sidebar/playlists остались заглушкой;
- Library снова заполнена Nirvana/Daft Punk;
- regressions не проверены.

Нужен не очередной визуальный апдейт, а стабилизация продукта: единая навигация, единый playback, единый search, нормальная library, нормальные loading states и отсутствие откатов.

Ключевая формулировка: **"regression lock before new visuals"**. Пусть сначала докажет, что старое не откатилось, а уже потом делает красоту. Сейчас у него типичный AI-паттерн: "выглядит обновленно", но state/navigation/playback разваливаются.

## 14. Search input должен работать как в адекватных плеерах

Сейчас при вводе текста поиск долго грузится и бесит. Нельзя, чтобы каждый символ превращал UI в тупую загрузку.

Сделать нормальный search UX:
- debounce input примерно 250-350ms;
- не блокировать UI во время ввода;
- показывать instant local/filter results, если они есть;
- remote search запускать после debounce;
- отменять предыдущий request при новом символе;
- stale responses не должны перетирать новые результаты;
- loading indicator должен быть маленький и локальный, не ломать весь экран;
- сохранять предыдущие результаты до прихода новых, но с аккуратным "searching..." state;
- кешировать последние queries;
- пустой query возвращает нормальный catalog/library state;
- поиск не должен сбрасывать player и navigation.

Acceptance:
- можно быстро печатать, UI не фризит;
- нет длинной тупой загрузки на каждый символ;
- старые результаты не мигают мусором;
- play из search работает;
- кнопки после search не умирают.

## 15. Artist header слишком огромный

Сейчас верхняя часть artist card занимает слишком много места. Это выглядит как огромный hero-заглушка, а не polished music app.

Переделать artist header:
- сделать ниже и плотнее;
- уменьшить пустое пространство сверху;
- artist image не должен висеть в огромной пустой зоне;
- metadata/actions должны быть ближе и компактнее;
- latest release должен быть виден без ощущения, что половина экрана потрачена на баннер;
- gradient/background должен быть тонким, не гигантской мутной стеной;
- header должен выглядеть как Apple Music / Spotify artist page: крупно, но не бессмысленно огромно.

Acceptance:
- на 1280x900 видно artist header + latest release + начало popular tracks;
- верх не съедает экран;
- карточка артиста выглядит богато, но плотнее.

## 16. Popular Tracks не показывать 100 штук сразу

Показывать 100 tracks вниз сразу — бред. Это ломает страницу.

Нужно:
- по умолчанию показывать только top 5 popular tracks;
- ниже кнопка "Show more" / "Показать еще";
- после раскрытия можно показать 20/50/100 или весь список с pagination/virtualization;
- кнопка должна уметь свернуть обратно;
- счетчик может писать "100 tracks", но список по умолчанию не должен быть на 100 строк;
- если треков много, использовать lazy render/virtualized list, чтобы не тормозило.

Acceptance:
- artist page сначала компактная;
- видно только 5 популярных треков;
- пользователь сам раскрывает остальное;
- mini player не перекрывает важные строки;
- скролл не превращается в простыню.

Не надо компенсировать плохую архитектуру визуалом. Сначала search/playback/navigation/loading должны работать как цельный player, потом polish.

## 17. Performance / loading must be production-grade

Сейчас приложение ощущается тяжелым: поиск подвисает, загрузка долгая, UI может показывать мусор или фризить. Нужно не просто "добавить loader", а реально оптимизировать поведение под медленный интернет.

Цель:
даже на очень медленном соединении app должен оставаться отзывчивым, чистым и предсказуемым.

Что сделать:
- все network requests должны быть cancellable через AbortController;
- search requests отменяются при новом вводе;
- stale responses не имеют права перетирать свежие данные;
- debounce search input 250-350ms;
- не запускать remote search на каждый символ без контроля;
- показывать результаты из cache мгновенно, если query уже был;
- использовать optimistic/local state там, где возможно;
- не блокировать весь экран из-за загрузки одного блока;
- loading должен быть granular: грузится search — показываем loader только в search area, не весь app;
- player, sidebar, navigation и current track не должны фризиться во время загрузок;
- lazy-load тяжелые секции: artist tracks, albums, lyrics, recommendations;
- images грузить lazy, с blur/skeleton placeholder;
- не грузить 100 tracks сразу, если пользователь видит только top 5;
- не рендерить огромные списки без virtualization/windowing;
- мемоизировать тяжелые компоненты и derived data;
- убрать лишние re-render'ы при каждом keypress;
- проверить useEffect dependencies, чтобы не было request loop;
- не пересоздавать player/search/navigation stores без причины;
- prefetch делать аккуратно: только вероятные next screens, не весь мир сразу;
- добавить request timeout и нормальный retry state;
- если интернет медленный, UI должен показывать спокойный skeleton/partial data, а не fake content;
- если запрос упал, показать нормальный error state + retry, не ломать экран.

Search performance acceptance:
- быстро печатаю 10-20 символов подряд — input не лагает;
- UI не фризится;
- предыдущие запросы отменяются;
- старые ответы не ломают новые результаты;
- loader маленький и локальный;
- play из search работает даже пока другие результаты догружаются;
- navigation после search не умирает.

Slow internet acceptance:
- включить throttling Slow 3G / Fast 3G в DevTools или Playwright;
- открыть app;
- поискать artist/track;
- перейти artist page;
- открыть lyrics;
- запустить track;
- UI должен оставаться usable все время;
- не должно быть fake Nirvana / Daft Punk / placeholder garbage;
- player должен продолжать работать во время загрузки;
- skeleton states должны выглядеть clean, не как сломанный layout.

Performance verification mandatory:
- проверить bundle size;
- проверить лишние network requests;
- проверить repeated requests на один и тот же query;
- проверить re-renders при typing;
- проверить artist page с 100 tracks;
- проверить search на slow network;
- записать результаты в docs/IMPLEMENTATION_NOTES.md и docs/BUGS_AND_REGRESSIONS.md.

Не закрывать задачу, пока app не ощущается быстрым. Красивый UI, который лагает при поиске и медленном интернете, считается невыполненной задачей.

Да, тогда формулируй не как "ускорь", а как найди root cause, почему UI ждет сеть.

## 18. Root-cause performance investigation: why search/UI waits for loading

Проблема не только в search. Весь app местами подвисает и ждет загрузки. Это архитектурный баг.

Нужно не просто добавить debounce/skeleton, а разобраться, почему Яндекс Музыка даже на 3G дает ощущение мгновенного поиска и навигации, а наш app ждет network и фризит UI.

Задача:
сначала провести performance investigation, потом исправить найденные причины.

Проверить и найти:
- какие компоненты блокируют render до прихода network data;
- где используется await перед обновлением UI;
- где route/page ждет data перед отображением shell;
- где search input связан с remote request так, что typing зависит от сети;
- где loading state перекрывает весь экран вместо отдельного блока;
- где старые данные удаляются до прихода новых;
- где каждый keypress триггерит тяжелый render;
- где пересоздаются большие массивы/объекты;
- где useEffect делает каскад запросов;
- где player/sidebar/navigation завязаны на один общий loading state;
- где API calls идут последовательно, хотя могут идти параллельно;
- где нет cache/stale-while-revalidate;
- где картинки/lyrics/tracks грузятся синхронно и тормозят страницу;
- где список 100 tracks рендерится сразу и убивает scroll/render;
- где animation/blur/backdrop-filter слишком тяжелые.

Нужно сделать как у нормального music app:
- app shell отображается мгновенно;
- sidebar/player/navigation не зависят от загрузки search/results;
- input всегда controlled локально и никогда не ждет request;
- search results работают через cache + stale-while-revalidate;
- старые результаты остаются на экране, пока новые догружаются;
- network loading не блокирует typing/clicks/playback;
- критичные данные грузятся первыми;
- тяжелые данные догружаются потом;
- route transition не должен быть blank/loading wall;
- player должен жить отдельно от loading состояния страниц;
- UI должен быть usable даже если API отвечает 3-5 секунд.

Сравнительная цель:
Яндекс Музыка на 3G ощущается быстрой не потому, что интернет магический, а потому что:
- input локальный;
- shell уже отрисован;
- есть cache;
- есть stale data;
- запросы не блокируют UI;
- loading локальный;
- heavy content lazy-loaded;
- player отделен от page fetching.

Сделать такую же модель поведения.

Implementation requirements:
- ввести нормальный client-side cache для search/artist/album/lyrics;
- использовать stale-while-revalidate pattern;
- разделить global app state и page loading state;
- убрать общий isLoading, который блочит весь app;
- заменить blocking loaders на skeleton/partial rendering;
- отменять устаревшие search requests;
- распараллелить независимые requests;
- lazy-load artist popular tracks после первых 5;
- lazy-load lyrics/recommendations/extra sections;
- virtualize длинные списки;
- memoize heavy lists/cards;
- проверить React Profiler / performance timeline;
- убрать лишние re-renders при typing.

Acceptance:
- при Slow 3G input печатает без задержки;
- search query меняется мгновенно локально;
- UI не ждет API, чтобы реагировать на clicks;
- player не останавливается и не фризится;
- navigation не становится dead во время загрузки;
- страницы открываются shell-first, data-after;
- нет full-screen loading wall после каждого действия;
- старые результаты не исчезают в пустоту при новом query;
- 100 tracks не рендерятся сразу;
- app остается usable при API delay 3-5 seconds.

Mandatory report:

В docs/IMPLEMENTATION_NOTES.md написать:
- где была настоящая причина подвисаний;
- какие компоненты блокировали UI;
- какие requests были лишними/последовательными;
- где убран global loading;
- где добавлен cache/stale-while-revalidate;
- как проверялось на Slow 3G;
- что осталось потенциально тяжелым.

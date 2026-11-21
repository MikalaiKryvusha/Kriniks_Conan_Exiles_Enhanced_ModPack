// KrinikConanText — every word the player reads in the launcher, in Russian and in English (KUMM plans/57, criteria 10–11).
// Слово владельца 2026-11-18 15:08 (передано главной сессией): «лаунчер должен будет поддерживать многоязычность. В нем должен быть свитч языка
// слева от блока кнопок закрытия, разворачивания и номера версии» · «лаунчер по-умолчанию запускается в языке системы юзера. Если настройку юзер
// поменял - лаунчер запоминает настройку юзера и запускается в выбранном юзером языке».
// Поэтому: одна таблица ключ → (русский, английский) — других видимых игроку строк в лаунчере нет (журнал лаунчера — для разработчика, он по-русски,
// и стенд читает его строки). Первый запуск — язык интерфейса Windows (CurrentUICulture: ru → русский, любой другой → английский); выбор игрока
// хранится в папке состояния лаунчера (State.Dir, на стенде — KRINIK_LAUNCHER_STATE_DIR) и открывает каждый следующий запуск.
// Русские строки состояний — с макетов design/mockups.html; английские написаны по смыслу, не словом в слово (KUMM AGENT_GUIDE → «The storefront», 1).
// [NOT-TESTED]
using System;
using System.Collections.Generic;
using System.Globalization;

static class Ui
{
    public enum Lang { Ru, En }
    public static Lang Current { get; private set; } = Lang.Ru;
    // Окно перерисовывает себя целиком, когда игрок сменил язык (без перезапуска).
    public static event Action Changed;
    const string LANG_FILE = "language.txt";
    // Язык системы на стенде: тот же код, что у Windows (ru-RU, en-US), — без смены языка Windows владельца. У игрока этой переменной нет.
    const string SYSTEM_VARIABLE = "KRINIK_LAUNCHER_SYSTEM_LANG";

    static readonly Dictionary<string, string[]> table = new Dictionary<string, string[]>(StringComparer.Ordinal);
    static void S(string key, string ru, string en) => table[key] = new[] { ru, en };

    static Ui()
    {
        // --- окно
        S("window.title", "Сборка модов Krinik Mod Pack {0} для Conan Exiles Enhanced {1}", "Krinik Mod Pack {0} for Conan Exiles Enhanced {1}");
        S("head.title", "Сборка модов Krinik Mod Pack {0}", "Krinik Mod Pack {0}");
        S("caps.minimize", "Свернуть", "Minimize");
        S("caps.close", "Закрыть", "Close");
        S("caps.language", "Язык окна", "Window language");
        // Имя языка в выпадающем списке — на нём самом, одно в обеих таблицах (`[OWNER]` 2026-11-18 15:55, макет «language»).
        S("lang.name.ru", "Русский", "Русский");
        S("lang.name.en", "English", "English");
        S("launcher.version", "Лаунчер: {0}", "Launcher: {0}");
        S("notes", "Что нового", "What's new");
        S("link.Почта", "Почта", "Email");
        // --- кнопки столбика
        S("btn.play", "Играть", "Play");
        S("btn.install", "Установить сборку", "Install mod pack");
        S("btn.pick", "Указать папку игры", "Choose game folder");
        S("btn.resume", "Продолжить скачивание", "Resume download");
        S("btn.retry", "Проверить ещё раз", "Check again");
        S("btn.stop", "Остановить", "Stop");
        S("btn.guide", "Руководство", "User guide");
        S("btn.feedback", "Отзыв", "Feedback");
        S("btn.uninstall", "Удалить сборку", "Remove mod pack");
        S("btn.update", "Обновить сборку", "Update mod pack");
        S("btn.update.launcher", "Обновить лаунчер", "Update launcher");
        // --- список состояния: подписи (макеты design/mockups.html, коммит пака 95f8b52 — русский переписан по методичкам ядра, 2026-11-18 15:15)
        S("st.folder", "Папка игры", "Game folder");
        S("st.version", "Версия игры", "Game version");
        S("st.build", "Сборка", "Mod pack");
        S("st.files", "Файлы сборки", "Mod pack files");
        S("st.need", "Нужно скачать", "To download");
        // Первая установка по списку файлов: размер известен только после сверки папки игры (судья 2026-11-21, круг 5, дефект 1: строка называла 0,1 МБ).
        S("v.need.after", "лаунчер посчитает, когда сверит файлы", "the launcher counts it when it has compared the files");
        S("st.search", "Поиск игры", "Game search");
        S("st.copies", "Найдено копий", "Copies found");
        S("st.game", "Игра", "Game");
        S("st.downloaded", "Скачано", "Downloaded");
        S("st.speed", "Скорость", "Speed");
        S("st.left", "Осталось времени", "Time left");
        S("st.elapsed", "Прошло времени", "Time spent");
        S("st.drives", "Проверено дисков", "Drives checked");
        S("st.now", "Сейчас проверяется", "Checking now");
        S("st.mods", "Скопировано модов", "Mods copied");
        S("st.checked", "Проверено", "Checked");
        S("st.unpacked", "Распаковано", "Unpacked");
        S("st.copied", "Скопировано", "Copied");
        S("st.latest", "Последняя сборка", "Latest mod pack");
        // --- список состояния: значения
        S("v.drive", "диск {0}", "drive {0}");
        S("v.of", "{0} из {1}", "{0} of {1}");
        S("v.search.done", "закончен", "finished");
        // Неразрывные пробелы ( ) держат вместе предлог и слово, как &nbsp; макета (75b310e).
        S("v.notfound", "Лаунчер не нашёл игру ни в библиотеках Steam, ни в папках Games на дисках, ни в Program Files.",
                        "The launcher did not find the game in the Steam libraries, in the Games folders of the drives or in Program Files.");
        S("v.pick.hint", "Если игра установлена в другой папке, нажмите «Указать папку игры» и выберите эту папку.",
                         "If the game is installed in another folder, press «Choose game folder» and pick that folder.");
        S("v.build.for", "{0} для игры {1}", "{0} for game {1}");
        S("v.removing", "Программа удаления сборки работает в отдельном окне. Когда окно закроется, лаунчер снова покажет состояние игры.",
                        "The build's uninstaller is running in its own window. When that window closes, the launcher shows the state of the game again.");
        S("v.files.beside", "уже лежат рядом с лаунчером", "already next to the launcher");
        S("v.files.unpacked", "уже распакованы в папке игры", "already unpacked in the game folder");
        S("v.files.github", "лаунчер скачает с GitHub", "the launcher downloads them from GitHub");
        S("v.net.stop", "Связь с GitHub прервалась, и скачивание остановилось.", "The connection to GitHub broke off, and the download stopped.");
        S("v.user.stop", "Вы остановили скачивание.", "You paused the download.");
        S("v.error.stop", "Лаунчер остановил скачивание из-за ошибки.", "The launcher stopped the download because of an error.");
        S("v.unfinished.stop", "Лаунчер не закончил скачивание сборки.", "The launcher has not finished downloading the build.");
        S("v.kept", "Лаунчер сохранил скачанные файлы и докачает только недостающие.", "The launcher kept the downloaded files and will fetch only the missing ones.");
        S("v.noversion", "Сборка для игры {0} ещё не вышла.", "No mod pack for game {0} has come out yet.");
        S("v.keep.open", "Не закрывайте лаунчер, пока идёт установка.", "Keep the launcher open while the installation runs.");
        // Состояния, которых нет на 12 макетах (HOUSE_RULES 23: перечислены в отчёте работы): лента ещё читается и лента не ответила. [NOT-TESTED]
        S("v.feed.wait", "лаунчер проверяет выпуски на GitHub", "the launcher is checking the releases on GitHub");
        S("v.feed.none", "Лаунчер не связался с GitHub и пока не знает, какая сборка подходит этой игре.",
                         "The launcher could not reach GitHub and does not know yet which mod pack fits this game.");
        S("v.cl", "CL-{0}", "CL-{0}");
        S("v.speed.wait", "ожидание данных", "waiting for data");
        S("v.left.wait", "оценивается", "estimating");
        // --- полоса прогресса
        S("p.search", "Поиск игры на дисках", "Looking for the game on the drives");
        S("p.download", "Скачивание сборки {0}", "Downloading mod pack {0}");
        S("p.verify", "Проверка файлов сборки {0}", "Checking the files of mod pack {0}");
        S("p.unpack", "Распаковка сборки {0}", "Unpacking mod pack {0}");
        S("p.remove", "Удаление прежней сборки", "Removing the previous mod pack");
        S("p.install", "Установка сборки {0}", "Installing mod pack {0}");
        S("p.update", "Обновление сборки до {0}", "Updating the mod pack to {0}");
        S("p.launcher", "Обновление лаунчера до {0}", "Updating the launcher to {0}");
        // --- плашка обновлений
        S("plate.build", "Вышла сборка {0} для игры {1}", "Mod pack {0} for game {1} is out");
        S("plate.launcher", "Вышел лаунчер {0}", "Launcher {0} is out");
        // --- выбор копии игры
        S("m.title", "Найдено копий игры: {0}", "Game copies found: {0}");
        S("m.text", "Выберите, в какую копию игры установить сборку. Лаунчер подберёт последнюю сборку для версии игры в выбранной копии.",
                    "Choose the copy of the game to install the mod pack into. The launcher picks the latest mod pack for the game version of that copy.");
        S("m.clean", "без модов", "no mods");
        S("m.krinik", "установлена сборка {0}", "mod pack {0} installed");
        S("m.krinik.any", "установлена сборка", "mod pack installed");
        S("m.other", "установлены другие моды", "other mods installed");
        S("m.fits", "{0}, подойдёт сборка {1}", "{0}, mod pack {1} fits");
        S("m.none", "сборка для этой версии ещё не вышла", "no mod pack for this version yet");
        S("m.cancel", "Отмена", "Cancel");
        S("m.list", "Копии игры", "Game copies");
        // --- выбор папки игры
        S("pick.title", "Папка игры Conan Exiles: в ней лежит ConanSandbox.exe", "The Conan Exiles folder, the one that holds ConanSandbox.exe");
        S("pick.wrong", "В папке {0} нет игры Conan Exiles: в ней нет файла ConanSandbox.exe.\n\nУкажите папку, в которую установлена игра.",
                        "The folder {0} holds no Conan Exiles: there is no ConanSandbox.exe in it.\n\nChoose the folder the game is installed in.");
        // --- табличка «Отзыв»
        S("report.title", "Как прислать отзыв или отчёт о падении", "How to send feedback or a crash report");
        S("report.1", "1. Нажмите «Собрать отчёт». Игру закрывать не обязательно.", "1. Press «Collect report». The game may stay open.");
        S("report.2", "2. Дождитесь строки «Готово»: на рабочем столе появится файл Conan-report-<дата>_<время>.zip.",
                      "2. Wait for the line «Done»: the file Conan-report-<date>_<time>.zip appears on your desktop.");
        S("report.3.mail", "3. Отправьте этот файл автору сборки письмом на почту {0} или приложите его к сообщению в разделе Issues на GitHub.",
                           "3. Send the file to the author of the mod pack by email to {0}, or attach it to a message in the Issues section on GitHub.");
        S("report.3", "3. Отправьте этот файл автору сборки письмом или приложите его к сообщению в разделе Issues на GitHub.",
                      "3. Send the file to the author of the mod pack by email, or attach it to a message in the Issues section on GitHub.");
        S("report.4", "4. Напишите, что происходило в игре перед падением.", "4. Write what was happening in the game before the crash.");
        S("report.note", "Вопрос по сборке и запрос на улучшение отправьте тем же путём, отчёт к ним не нужен.",
                         "Send a question about the mod pack or a request for an improvement the same way; they need no report.");
        S("report.collect", "Собрать отчёт", "Collect report");
        // --- окна сообщений
        S("box.notes", "Что нового", "What's new");
        S("box.link", "Не удалось открыть ссылку в браузере:\n{0}", "The browser did not open the link:\n{0}");
        S("box.install", "Установить сборку", "Install mod pack");
        S("box.uninstall", "Удалить сборку", "Remove mod pack");
        S("box.uninstall.ask", "Удалить сборку Krinik и вернуть игру в тот вид, в каком она была до установки сборки?\n\nЗакройте игру перед удалением.",
                               "Remove the Krinik mod pack and return the game to the state it had before the mod pack was installed?\n\nClose the game before removing.");
        S("box.update", "Обновить сборку", "Update mod pack");
        S("box.update.launcher", "Обновить лаунчер", "Update launcher");
        S("box.busy.title", "Обновление", "Update");
        S("box.busy", "Идёт обновление или установка. Дождитесь их конца или нажмите «Остановить», пока скачиваются файлы сборки.",
                      "An update or an installation is running. Wait until it ends, or press «Stop» while the mod pack files download.");
        S("box.console", "Открыто окно установки или удаления сборки. Дождитесь его конца.", "A mod pack installation or removal window is open. Wait until it ends.");
        S("box.other", "Обновление уже идёт в другом окне лаунчера.", "An update is already running in another launcher window.");
        S("box.space", "Для установки на диске {0} нужно {1} свободного места, а свободно {2}.", "The installation needs {1} of free space on drive {0}; {2} is free.");
        S("box.update.ready", "Сборка {0} уже скачана и распакована:\n{1}\n\nПоставить её вместо {2}?{3}\nИгру на время обновления закройте.",
                              "Mod pack {0} is already downloaded and unpacked:\n{1}\n\nInstall it in place of {2}?{3}\nClose the game for the time of the update.");
        S("box.update.ask", "Скачать сборку {0} ({1}) и поставить её вместо {2}?{3}\n\nАрхив скачается в папку игры, после распаковки его части удалятся.{4}\nИгру на время обновления закройте.",
                            "Download mod pack {0} ({1}) and install it in place of {2}?{3}\n\nThe archive downloads into the game folder; its parts are deleted after unpacking.{4}\nClose the game for the time of the update.");
        S("box.update.have", " Уже скачано {0}, докачка продолжится.", " {0} is already downloaded; the download continues from there.");
        // Путь по списку файлов негоден: причина первой, вопрос в конце (судья 2026-11-21, круг 3, чистое чтение строк). Круг 4: «обновить только изменившиеся
        // файлы» читалось двояко (не удалось обновить одни лишь изменившиеся) — «обновить сборку по изменившимся файлам».
        S("box.update.ask.whole", "Лаунчер не смог обновить сборку по изменившимся файлам. Скачать всю сборку {0} ({1}) и поставить её вместо {2}?\n\nАрхив скачается в папку игры, после распаковки его части удалятся.{3}\nИгру на время обновления закройте.",
                                  "The launcher could not update the mod pack by its changed files alone. Download the whole mod pack {0} ({1}) and install it in place of {2}?\n\nThe archive downloads into the game folder; its parts are deleted after unpacking.{3}\nClose the game for the time of the update.");
        S("box.update.free", " На диске {0} свободно {1}.", " Drive {0} has {1} free.");
        S("box.update.placed", "Сборка {0} поставлена. Лаунчер новой сборки лежит в {1}.", "Mod pack {0} is installed. The launcher of the new mod pack is in {1}.");
        S("box.installed", "Сборка {0} поставлена.", "Mod pack {0} is installed.");
        S("box.oldbundle.title", "Прежняя сборка", "Previous mod pack");
        // Вопрос последним (круг 4): сначала что освободится, потом «Удалить папку?»; «на диске» один раз.
        S("box.oldbundle", "Новая сборка установлена. Папка прежней сборки больше не нужна:\n{0}\n\nЕсли удалить эту папку, на диске освободится {1}.{2}\n\nУдалить папку?",
                           "The new mod pack is installed. The folder of the previous one is no longer needed:\n{0}\n\nDeleting this folder frees {1} on the disk.{2}\n\nDelete the folder?");
        S("box.oldbundle.shared", " Файлы, которые не изменились, останутся: ими пользуется новая сборка.",
                                  " The unchanged files stay: the new mod pack uses them.");
        S("box.crash.title", "Отчёт о падении игры", "Game crash report");
        S("box.crash", "Игра в прошлый раз закрылась с ошибкой.\n\nСобрать отчёт для автора сборки? Файл отчёта появится на рабочем столе, а в браузере " +
                       "откроется новое сообщение в разделе Issues на GitHub. Приложите к нему файл отчёта и напишите, что происходило в игре перед падением.",
                       "Last time the game closed with an error.\n\nCollect a report for the author of the mod pack? The report file appears on your desktop, and the browser " +
                       "opens a new message in the Issues section on GitHub. Attach the report file to it and write what was happening in the game before the crash.");
        S("box.crash.issue", "Падение игры: сборка {0}, игра {1}", "Game crash: mod pack {0}, game {1}");
        S("box.report.fail", "Отчёт не собран: программа сбора отчёта не запустилась.\n\nЗапустите файл collect_report.cmd из папки сборки вручную.",
                             "No report was collected: the report program did not start.\n\nRun the file collect_report.cmd from the mod pack folder yourself.");
        S("box.error", "Лаунчер столкнулся с ошибкой:\n\n{0}", "The launcher ran into an error:\n\n{0}");
        S("box.error.exit", "Лаунчер столкнулся с ошибкой и сейчас закроется.\n\n{0}", "The launcher ran into an error and will close now.\n\n{0}");
        S("box.slot", "Лаунчер не смог вернуть свой файл на место.\n\nОткройте папку {0} и переименуйте файл {1} в {2}.",
                      "The launcher could not put its file back in place.\n\nOpen the folder {0} and rename the file {1} to {2}.");
        // --- итоги обновления сборки (BuildUpdate.Run)
        S("u.game.running", "Игра запущена. Закройте её и нажмите «{0}» ещё раз.", "The game is running. Close it and press «{0}» again.");
        S("u.game.running.ready", "Игра запущена. Закройте её и нажмите «{0}» ещё раз: сборка {1} уже скачана и распакована.",
                                  "The game is running. Close it and press «{0}» again: mod pack {1} is already downloaded and unpacked.");
        S("u.console", "Открыто окно установки или удаления сборки. Дождитесь его конца и нажмите «{0}» ещё раз.",
                       "A mod pack installation or removal window is open. Wait until it ends and press «{0}» again.");
        S("u.tail", "В выпуске {0} не хватает частей архива: последняя часть {1} не завершает архив. Ничего не скачано; сообщите автору сборки.",
                    "Release {0} lacks parts of the archive: the last part {1} does not end the archive. Nothing was downloaded; please tell the author of the mod pack.");
        S("u.twice", "{0} дважды скачалась с ошибкой. Проверьте сеть и нажмите «{1}» ещё раз.", "{0} downloaded with an error twice. Check the network and press «{1}» again.");
        S("u.beside.bad", "Файл {0} рядом с лаунчером не совпал с выпуском {1} по контрольной сумме. Удалите его, и лаунчер скачает этот файл заново.",
                          "The file {0} next to the launcher does not match release {1} by its checksum. Delete it, and the launcher downloads the file again.");
        S("u.no.installer", "В архиве сборки нет install.ps1. Распакованная сборка лежит в {0}.", "The mod pack archive has no install.ps1. The unpacked mod pack is in {0}.");
        S("u.wrong.version", "В архиве выпуска {0} лежит сборка «{1}». Прежняя сборка не тронута; сообщите автору сборки.",
                             "The archive of release {0} holds mod pack «{1}». The previous mod pack is untouched; please tell the author of the mod pack.");
        S("u.not.removed", "Прежняя сборка не удалилась. Запустите {0} в папке игры, потом install.cmd в {1}.",
                           "The previous mod pack was not removed. Run {0} in the game folder, then install.cmd in {1}.");
        S("u.partial", "Сборка {0} встала не полностью (код {1}). Запустите install.cmd в {2} и пришлите автору сборки снимок его окна.",
                       "Mod pack {0} was installed only in part (code {1}). Run install.cmd in {2} and send the author of the mod pack a screenshot of its window.");
        // Остановленная первая установка по списку файлов (круг 5, дефект 2: окно молча возвращалось к началу).
        S("u.stopped.install", "Установка остановлена, скачанное сохранено. Нажмите «Установить сборку» ещё раз, и лаунчер продолжит с того же места.",
                               "The installation is paused; what was downloaded is kept. Press «Install mod pack» again, and the launcher continues from the same place.");
        S("u.stopped", "Обновление остановлено. Скачанное сохранено: следующее нажатие продолжит с того же места.",
                       "The update is paused. What was downloaded is kept: the next press continues from the same place.");
        S("u.failed", "Сборка не обновилась: {0}", "The mod pack was not updated: {0}");
        // Причины для u.failed — продолжение фразы после двоеточия, со строчной буквы.
        S("u.bad.path", "в архиве сборки путь файла {0} ведёт за пределы папки сборки", "in the build archive the path of the file {0} leads outside the build folder");
        S("u.bad.archive", "лаунчер не смог прочитать архив сборки", "the launcher could not read the build archive");
        S("u.no.game", "Игра не найдена: укажите папку игры.", "The game was not found: choose the game folder.");
        S("u.never", "Эта папка игры записана в список запретных папок лаунчера (never.txt), и лаунчер не ставит в неё сборку.",
                     "This game folder is on the launcher's list of forbidden folders (never.txt), and the launcher does not install the mod pack into it.");
        S("u.no.archive", "В выпуске {0} нет полного архива сборки с контрольными суммами. Скачайте сборку со страницы выпуска.",
                          "Release {0} has no complete mod pack archive with checksums. Download the mod pack from the release page.");
        S("u.over.self", "Сборка {0} распаковалась бы поверх папки, из которой запущен лаунчер. Скачайте её со страницы выпуска.",
                         "Mod pack {0} would unpack over the folder the launcher runs from. Download it from the release page.");
        // --- обновление по списку файлов выпуска (KrinikConanDelta.cs, KUMM plans/57 фаза 6)
        // Первая установка по списку файлов (KUMM plan 57 фаза 6 шаг 6): вопрос с настоящим размером после сверки папки игры (круг 5, дефект 1).
        // Чистое чтение 2026-11-21 17:3x: «сборка» вместо второго слова «выпуск», действует лаунчер, а не «распаковка».
        S("box.delta.install", "Установить сборку {0}?\n\nЛаунчер сверил папку игры со списком файлов сборки. Нужно скачать {1} (файлов: {2}).{3}\nИгру на время установки закройте.",
                               "Install mod pack {0}?\n\nThe launcher compared the game folder with the mod pack's file list. It needs to download {1} ({2} files).{3}\nClose the game for the time of the installation.");
        S("box.install.ask.whole", "Лаунчер не смог установить сборку по отдельным файлам. Скачать всю сборку {0} одним архивом ({1})?\n\nЛаунчер скачает архив в папку игры, распакует его и удалит.{2}\nИгру на время установки закройте.",
                                   "The launcher could not install the mod pack file by file. Download the whole mod pack {0} as one archive ({1})?\n\nThe launcher downloads the archive into the game folder, unpacks it and deletes it.{2}\nClose the game for the time of the installation.");
        S("box.delta.ask", "Обновить сборку с {3} до {0}?\n\nЛаунчер сверил файлы прежней сборки со списком файлов нового выпуска. Нужно скачать {1} (файлов: {2}). " +
                           "Остальные файлы лаунчер возьмёт из прежней сборки.{4}\nИгру на время обновления закройте.",
                           "Update the mod pack from {3} to {0}?\n\nThe launcher compared the files of the previous mod pack with the file list of the new release. " +
                           "It needs to download {1} ({2} files). The launcher takes the other files from the previous mod pack.{4}\nClose the game for the time of the update.");
        S("u.delta.missing", "В выпуске {0} нет файла {1}, который назван в списке файлов этого выпуска. Скачайте сборку со страницы выпуска.",
                             "Release {0} lacks the file {1} named in the file list of this release. Download the mod pack from the release page.");
        S("u.delta.differs", "В выпуске {0} файл {1} не совпадает со своей записью в списке файлов. Скачайте сборку со страницы выпуска.",
                             "In release {0} the file {1} does not match its entry in the file list. Download the mod pack from the release page.");
        S("u.delta.twice", "Файл {0} дважды скачался с ошибкой. Проверьте сеть и нажмите «{1}» ещё раз.",
                           "The file {0} downloaded with an error twice. Check the network and press «{1}» again.");
        S("u.delta.bad.list", "Лаунчер не смог прочитать список файлов выпуска {0}. Скачайте сборку со страницы выпуска.",
                              "The launcher could not read the file list of release {0}. Download the mod pack from the release page.");
        S("u.delta.root", "Список файлов выпуска {0} называет папку сборки {1}, которая не подходит к номеру этого выпуска. Скачайте сборку со страницы выпуска.",
                          "The file list of release {0} names the mod pack folder {1}, which does not fit the number of this release. Download the mod pack from the release page.");
        // Причины для u.failed — продолжение фразы после двоеточия, со строчной буквы.
        S("u.delta.path", "в списке файлов выпуска путь файла {0} ведёт за пределы папки сборки", "in the file list of the release the path of the file {0} leads outside the mod pack folder");
        S("u.delta.bad","контрольная сумма файла {0} новой сборки не совпала с указанной в списке файлов выпуска",
                         "the checksum of the file {0} of the new mod pack does not match the one in the file list of the release");
        // --- итоги самообновления (SelfUpdate.Run)
        S("s.no.asset", "В выпуске лаунчера {0} нет файла {1}.", "Launcher release {0} has no file {1}.");
        S("s.no.digest", "У файла {0} в выпуске нет контрольной суммы. Файл без контрольной суммы лаунчер не скачивает.", "The file {0} of the release has no checksum. The launcher does not download a file without one.");
        S("s.keep.old", "Лаунчер сначала должен вернуться на прежнюю версию. Закройте его, откройте заново и проверьте обновления ещё раз.",
                        "The launcher first has to return to its previous version. Close it, start it again, then check for updates once more.");
        S("s.digest.bad", "Скачанный лаунчер не совпал с выпуском по контрольной сумме. Прежний лаунчер остался на месте.",
                          "The downloaded launcher does not match the release by its checksum. The previous launcher stays in place.");
        S("s.not.started", "Новый лаунчер {0} не запустился ({1}). Прежний лаунчер вернулся на место.", "The new launcher {0} did not start ({1}). The previous launcher is back in place.");
        S("s.no.window", "Новый лаунчер {0} запустился, но не открыл окно. Прежний лаунчер вернулся на место; сообщите автору сборки.",
                         "The new launcher {0} started but opened no window. The previous launcher is back in place; please tell the author of the mod pack.");
        S("s.failed.back", "Лаунчер не обновился: {0}", "The launcher was not updated: {0}");
        S("s.no.write", "Нет права записи в папку {0}. Запустите лаунчер от имени администратора и повторите.",
                        "No right to write into the folder {0}. Run the launcher as administrator and try again.");
        S("s.failed", "Лаунчер не обновился: {0} Прежний лаунчер остался на месте.", "The launcher was not updated: {0} The previous launcher stays in place.");
        S("s.rollback.failed", "Лаунчер не обновился, и вернуть прежний не вышло: он лежит рядом как {0}. Переименуйте его в {1}.",
                               "The launcher was not updated, and the previous one could not be put back: it lies next to it as {0}. Rename it to {1}.");
        S("s.crashed", "Лаунчер не обновился: {0}", "The launcher was not updated: {0}");
        S("caption", "Krinik Mod Pack", "Krinik Mod Pack");
    }

    public static string T(string key)
    {
        if (!table.TryGetValue(key, out var pair)) return key;   // ключа нет — видно сразу, а не пустая строка
        return pair[(int)Current];
    }

    public static string F(string key, params object[] args) => string.Format(CultureInfo.InvariantCulture, T(key), args);

    // Подпись ссылки автора (author_links.txt пишет её по-русски): у «Почта» есть перевод, имена сайтов одни на всех языках.
    public static string LinkText(string text) => table.ContainsKey("link." + text) ? T("link." + text) : text;

    static CultureInfo Culture => CultureInfo.GetCultureInfo(Current == Lang.Ru ? "ru-RU" : "en-US");
    const double GB = 1073741824.0, MB = 1048576.0;

    public static string Size(long bytes)
    {
        bool ru = Current == Lang.Ru;
        return bytes >= GB ? (bytes / GB).ToString("0.0", Culture) + (ru ? " ГБ" : " GB") : Math.Max(0.1, bytes / MB).ToString("0.0", Culture) + (ru ? " МБ" : " MB");
    }

    // «2,5 из 6,8 ГБ»: обе величины в единицах целого, единица — один раз.
    public static string Amount(long done, long total)
    {
        bool ru = Current == Lang.Ru, gb = total >= GB;
        double k = gb ? GB : MB;
        string unit = gb ? (ru ? "ГБ" : "GB") : (ru ? "МБ" : "MB");
        return F("v.of", (done / k).ToString("0.0", Culture), (total / k).ToString("0.0", Culture)) + " " + unit;
    }

    public static string Speed(double bytesPerSecond) => (bytesPerSecond / MB).ToString("0.0", Culture) + (Current == Lang.Ru ? " МБ/с" : " MB/s");

    // «3 мин 55 с», «41 с», «1 ч 05 мин» — как на макетах.
    public static string Duration(TimeSpan t)
    {
        bool ru = Current == Lang.Ru;
        long s = Math.Max(0, (long)Math.Round(t.TotalSeconds));
        if (s >= 3600) return $"{s / 3600} {(ru ? "ч" : "h")} {s % 3600 / 60:00} {(ru ? "мин" : "min")}";
        if (s >= 60) return $"{s / 60} {(ru ? "мин" : "min")} {s % 60} {(ru ? "с" : "s")}";
        return $"{s} {(ru ? "с" : "s")}";
    }

    // Язык первого запуска — системы; выбранный игроком — из папки состояния. [NOT-TESTED]
    public static void Init()
    {
        string saved = State.Read(LANG_FILE);
        if (saved == "ru") { Current = Lang.Ru; return; }
        if (saved == "en") { Current = Lang.En; return; }
        string system = Environment.GetEnvironmentVariable(SYSTEM_VARIABLE);
        if (string.IsNullOrEmpty(system)) system = CultureInfo.CurrentUICulture.Name;
        Current = system.StartsWith("ru", StringComparison.OrdinalIgnoreCase) ? Lang.Ru : Lang.En;
        MetalWindow.Log("язык окна по языку системы " + system + ": " + Current);
    }

    // Код языка: имя файла выбора, ключи строк «lang.name.<код>», надпись поля выбора (заглавными).
    public static string Code(Lang lang) => lang == Lang.Ru ? "ru" : "en";

    public static void Set(Lang lang)
    {
        if (lang == Current) return;
        Current = lang;
        State.Write(LANG_FILE, Code(lang));
        MetalWindow.Log("язык окна выбран игроком: " + lang);
        Changed?.Invoke();
    }
}

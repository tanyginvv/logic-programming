:- encoding(utf8).
:- module(hotel_expert, [start/0, demo/0, diagnose/2, example/2]).
:- use_module(library(lists)).
:- use_module(library(readutil)).

% Учебный прототип. Все факты относятся к одному тарифу и запросу гостя.
% yes/no/unknown; отсутствие факта означает unknown, а не no.
question(rate_active, 'Тариф активен?').
question(website_enabled, 'Для тарифа выбран официальный сайт как источник продаж?').
question(payment_available, 'Есть хотя бы один способ оплаты, доступный для этого запроса?').
question(guest_matches, 'Состав гостей соответствует условиям тарифа?').
question(display_period_matches, 'Сегодняшняя дата и день недели входят в период показа?').
question(promo_required, 'Для доступа к тарифу требуется промокод?').
question(promo_valid, 'Гость ввел подходящий промокод?').
question(rooms_available, 'Есть категория с доступными номерами на каждую ночь проживания?').
question(sales_open, 'Продажи открыты для рассматриваемого запроса?').
question(categories_enabled, 'В тариф включена хотя бы одна активная категория номера?').
question(loyalty_required, 'Тариф предназначен только для участников программы лояльности?').
question(loyalty_matches, 'Гость соответствует требуемому уровню лояльности?').

% rule(ID, Priority, Conditions, Cause, Recommendation, Source).
% Меньшее число приоритета означает более ранний вывод, не вероятность.
rule(r01, 10, [rate_active-no], inactive_rate,
     'Проверьте необходимость активации тарифа.', activation).
rule(r02, 20, [website_enabled-no], website_disabled,
     'Проверьте подключение сайта в источниках тарифа.', visibility).
rule(r03, 30, [categories_enabled-no], no_active_categories,
     'Проверьте активные категории, включенные в тариф.', tariff_check).
rule(r04, 40, [rooms_available-no], no_inventory,
     'Проверьте наличие номеров на весь период проживания.', tariff_check).
rule(r05, 50, [sales_open-no], sales_closed,
     'Проверьте, намеренно ли закрыты продажи.', visibility).
rule(r06, 60, [payment_available-no], no_payment_method,
     'Проверьте доступность способов оплаты.', visibility).
rule(r07, 70, [guest_matches-no], guest_mismatch,
     'Сопоставьте состав гостей с условиями тарифа.', visibility).
rule(r08, 80, [display_period_matches-no], outside_display_period,
     'Проверьте расписание показа тарифа.', tariff_check).
rule(r09, 90, [promo_required-yes, promo_valid-no], promo_missing,
     'Проверьте введенный промокод.', tariff_check).
rule(r10, 100, [loyalty_required-yes, loyalty_matches-no], loyalty_mismatch,
     'Проверьте условия доступа по программе лояльности.', tariff_check).

source(activation, 'База правил: активность тарифа').
source(visibility, 'База правил: условия показа тарифа').
source(tariff_check, 'База правил: доступность тарифа').

% Проверка входных данных до вывода исключает противоречивые ответы.
validate(Facts) :-
    ( is_list(Facts), ground(Facts) -> true
    ; throw(error(invalid_facts(Facts), diagnose/2)) ),
    maplist(valid_fact, Facts),
    findall(Key, member(Key-_, Facts), Keys),
    sort(Keys, Unique),
    ( same_length(Keys, Unique) -> true
    ; throw(error(duplicate_keys, diagnose/2)) ).

valid_fact(Key-Value) :-
    question(Key, _), memberchk(Value, [yes, no, unknown]), !.
valid_fact(Fact) :- throw(error(invalid_fact(Fact), diagnose/2)).

value(Facts, Key, Value) :-
    ( memberchk(Key-V, Facts) -> Value = V ; Value = unknown ).

condition_true(Facts, Key-Expected) :- value(Facts, Key, Expected).
condition_possible(Facts, Key-Expected) :-
    value(Facts, Key, Actual), (Actual == unknown ; Actual == Expected).

% Обратный вывод: проверяем предпосылки каждой возможной причины.
% Возвращаем все сработавшие правила и недостающие факты для остальных.
diagnose(Facts, report(Status, Findings, Missing)) :-
    validate(Facts),
    findall(P-finding(Id, Cause, Action, Conditions, SourceRef),
            ( rule(Id, P, Conditions, Cause, Action, Source),
              maplist(condition_true(Facts), Conditions), source(Source, SourceRef) ),
            Pairs),
    keysort(Pairs, Sorted), pairs_values_local(Sorted, Findings),
    findall(Key,
            ( rule(_, _, Conditions, _, _, _),
              maplist(condition_possible(Facts), Conditions),
              member(Key-_, Conditions), value(Facts, Key, unknown) ),
            UnknownKeys),
    sort(UnknownKeys, Missing),
    report_status(Findings, Missing, Status).

pairs_values_local([], []).
pairs_values_local([_-V|Rest], [V|Values]) :- pairs_values_local(Rest, Values).

report_status([_|_], _, causes_found).
report_status([], [_|_], insufficient_data).
report_status([], [], no_known_cause).

% Эталонный пример без блокировок в рамках данной базы знаний.
example(clear, [rate_active-yes, website_enabled-yes, payment_available-yes,
               guest_matches-yes, display_period_matches-yes,
               promo_required-no, rooms_available-yes, sales_open-yes,
               categories_enabled-yes, loyalty_required-no]).
example(blocked, [rate_active-no, website_enabled-no, payment_available-yes,
                 guest_matches-yes, display_period_matches-yes,
                 promo_required-no, rooms_available-yes, sales_open-yes,
                 categories_enabled-yes, loyalty_required-no]).
example(incomplete, [rate_active-yes]).

demo :- example(blocked, Facts), diagnose(Facts, Report), print_report(Report).

start :-
    writeln('Экспертный модуль AI-ассистента платформы онлайн-бронирования отелей: диагностика тарифа.'),
    writeln('Рассматривайте один тариф, одни даты и один состав гостей.'),
    writeln('Ответы: yes, no, unknown (без точки). EOF завершает опрос.'),
    ask_remaining([], []).

ask_remaining(Facts, Asked) :-
    diagnose(Facts, Report), Report = report(_, _, Missing),
    subtract(Missing, Asked, Remaining),
    ( Remaining = [Key|_] ->
        question(Key, Text), format('~w~n> ', [Text]), flush_output,
        read_line_to_string(user_input, Line),
        ( Line == end_of_file -> print_report(Report)
        ; normalize_space(string(Clean), Line), string_lower(Clean, Lower),
          ( answer(Lower, Answer) -> ask_remaining([Key-Answer|Facts], [Key|Asked])
          ; writeln('Введите yes, no или unknown.'), ask_remaining(Facts, Asked) ) )
    ; print_report(Report) ).

answer("yes", yes).
answer("no", no).
answer("unknown", unknown).

print_report(report(Status, Findings, Missing)) :-
    format('~nСтатус: ~w~n', [Status]),
    maplist(print_finding, Findings),
    ( Missing == [] -> true ; format('Не хватает данных: ~w~n', [Missing]) ),
    ( Status == no_known_cause ->
        writeln('Известные правила не выявили причину. Это не гарантирует доступность.'),
        writeln('Используйте проверку тарифа или обратитесь в поддержку.')
    ; true ).

print_finding(finding(Id, Cause, Action, Evidence, SourceRef)) :-
    format('~nПравило: ~w; причина: ~w~nОснование: ~w~nСовет: ~w~nИсточник: ~w~n',
           [Id, Cause, Evidence, Action, SourceRef]).

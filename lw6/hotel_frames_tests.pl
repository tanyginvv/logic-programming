:- encoding(utf8).
:- use_module(hotel_frames).
:- begin_tests(hotel_frames).

test(exactly_two_instances) :-
    findall(O, instance(O), [standard_rate, promo_rate]).
test(two_levels) :-
    forall(instance(O), (parent(O,tariff), \+ parent(tariff,_))).
test(at_least_two_own_and_two_inherited_per_object) :-
    forall(instance(O),
           (describe(O,Ps),
            findall(S,member(property(S,_,own(O)),Ps),Own),
            findall(S,member(property(S,_,inherited(_)),Ps),Inherited),
            length(Own,NO), length(Inherited,NI), assertion(NO >= 2), assertion(NI >= 2))).
test(own_price) :- get_slot(standard_rate,price,5000,own(standard_rate)).
test(inherited_currency) :- get_slot(promo_rate,currency,rub,inherited(tariff)).
test(inherited_payment) :-
    get_slot(standard_rate,payment_method,on_arrival,inherited(tariff)).
test(override_minimum) :- get_slot(promo_rate,min_nights,3,own(promo_rate)).
test(no_fallback_to_overridden_value, [fail]) :- get_slot(promo_rate,min_nights,1,_).
test(other_object_keeps_default) :-
    get_slot(standard_rate,min_nights,1,inherited(tariff)).
test(standard_has_no_blockers) :-
    consult_tariff(standard_rate,2,report(no_known_blockers,[],[])).
test(promo_has_three_causes) :-
    consult_tariff(promo_rate,2,report(blocked,Fs,[])),
    findall(Id,member(finding(Id,_,_),Fs),[r01,r02,r04]).
test(minimum_boundary) :-
    consult_tariff(promo_rate,3,report(blocked,Fs,[])),
    findall(Id,member(finding(Id,_,_),Fs),[r01,r02]).
test(explanation_includes_origin) :-
    consult_tariff(promo_rate,2,report(blocked,Fs,[])),
    memberchk(finding(r04,_,[stay_evidence(2,3,own(promo_rate))]),Fs).
test(inherited_value_used_by_engine) :-
    hotel_frames:prove(standard_rate,2,eq(website_enabled,yes),
                           slot_evidence(website_enabled,yes,inherited(tariff))).
test(no_duplicate_local_slots) :-
    findall(F-S,slot(F,S,_),Keys), sort(Keys,Unique), same_length(Keys,Unique).
test(no_duplicate_effective_slots) :-
    forall(instance(O),(describe(O,Ps),findall(S,member(property(S,_,_),Ps),Keys),
                        sort(Keys,Unique),same_length(Keys,Unique))).
test(absent_slot_is_not_false, [fail]) :- get_slot(tariff,active,no,_).
test(unknown_object, [throws(error(unknown_object(_),_))]) :- consult_tariff(missing,2,_).
test(prototype_is_not_object, [throws(error(unknown_object(_),_))]) :- consult_tariff(tariff,2,_).
test(unknown_slot, [throws(error(unknown_slot(_),_))]) :- get_slot(promo_rate,typo,_,_).
test(zero_nights, [throws(error(invalid_nights(_),_))]) :- consult_tariff(standard_rate,0,_).
test(fractional_nights, [throws(error(invalid_nights(_),_))]) :- consult_tariff(standard_rate,1.5,_).

:- end_tests(hotel_frames).

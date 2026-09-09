:- encoding(utf8).
:- use_module(hotel_expert).
:- begin_tests(hotel).

test(two_causes) :-
    example(blocked, F),
    diagnose(F, report(causes_found, Findings, [])),
    findall(Id, member(finding(Id,_,_,_,_), Findings), [r01,r02]).
test(no_known_cause) :-
    example(clear, F), diagnose(F, report(no_known_cause, [], [])).
test(empty_is_unknown) :-
    diagnose([], report(insufficient_data, [], Missing)), length(Missing, 12).
test(explicit_unknown) :-
    diagnose([rate_active-unknown], report(insufficient_data, [], M)),
    memberchk(rate_active, M).
test(promo_conjunction) :-
    diagnose([promo_required-yes,promo_valid-no], report(causes_found, F, _)),
    memberchk(finding(r09,_,_,[promo_required-yes,promo_valid-no],_), F).
test(promo_irrelevant) :-
    diagnose([promo_required-no,promo_valid-no], report(insufficient_data, [], M)),
    \+ memberchk(promo_valid, M).
test(loyalty_conjunction) :-
    diagnose([loyalty_required-yes,loyalty_matches-no], report(causes_found,F,_)),
    memberchk(finding(r10,_,_,_,_),F).
test(partial_cause) :-
    diagnose([rate_active-no], report(causes_found, [finding(r01,_,_,_,_)], [_|_])).
test(reject_conflict, [throws(error(duplicate_keys,_))]) :-
    diagnose([rate_active-yes,rate_active-no], _).
test(reject_bad_value, [throws(error(invalid_fact(_),_))]) :-
    diagnose([rate_active-maybe], _).
test(reject_bad_key, [throws(error(invalid_fact(_),_))]) :- diagnose([typo-yes], _).
test(reject_variable, [throws(error(invalid_facts(_),_))]) :- diagnose([rate_active-_], _).
test(independent_sessions) :-
    diagnose([rate_active-no], _),
    diagnose([], report(insufficient_data, [], _)).
test(every_rule_can_fire) :-
    forall(hotel_expert:rule(Id,_,Conditions,_,_,_),
           (diagnose(Conditions, report(causes_found,F,_)),
            memberchk(finding(Id,_,_,Conditions,_), F))).

:- end_tests(hotel).

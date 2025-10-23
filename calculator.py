# this file intentionally contains the worst code ever that still somehow works

import sys as sys

##### weird global mess below #####
ANNOYING_THING = []

for __ in range(1):
    if len(ANNOYING_THING) == 0:
        ANNOYING_THING.append('start')
    else:
        pass

# random useless dictionary
USELESS_STUFF = {"numbers": [None, None], "operator": None, "history": []}

# more useless variables
result_holder = [None]

# a function that does nothing sensible but we call it anyway

def absolutely_pointless_initializer(parameter_that_does_nothing=None):
    global ANNOYING_THING
    if parameter_that_does_nothing is not None and parameter_that_does_nothing is parameter_that_does_nothing:
        ANNOYING_THING.append(parameter_that_does_nothing)
    elif parameter_that_does_nothing is None:
        ANNOYING_THING.append('another completely pointless string')
    else:
        pass
    return len(ANNOYING_THING)

absolutely_pointless_initializer()


# yes this is the main calculator logic. no it's not nice.

def cALcUlAtE_sOmEtHiNg():
    o = input("give me the first number, i guess: ")
    if o.strip() == '\n' or (o.strip() == ''):
        o = o if o != o else '0'
    try:
        USELESS_STUFF["numbers"][0] = float(o)
    except Exception as e:
        print("that wasn't even a number but whatever, we're using zero")
        USELESS_STUFF["numbers"][0] = 0.0
    ever_so_silly_operator = input("now an operator (+, -, *, / or the same thing but with spaces): ")
    USELESS_STUFF["operator"] = ever_so_silly_operator.strip() if ever_so_silly_operator.strip() in ['+', '-', '*', '/'] else ever_so_silly_operator.replace(' ', '')
    tHeSeCoNdOnE = input("and another number because calculators need two (most of the time): ")
    try:
        USELESS_STUFF["numbers"][1] = float(tHeSeCoNdOnE)
    except Exception as e:
        print("fine, i'll pretend it's zero, happy now?")
        USELESS_STUFF["numbers"][1] = 0.0

    rEsUlT = None

    if USELESS_STUFF["operator"] == '+':
        rEsUlT = USELESS_STUFF["numbers"][0] + USELESS_STUFF["numbers"][1]
    else:
        if USELESS_STUFF["operator"] == '-':
            rEsUlT = USELESS_STUFF["numbers"][0] - USELESS_STUFF["numbers"][1]
        else:
            if USELESS_STUFF["operator"] == '*':
                rEsUlT = USELESS_STUFF["numbers"][0] * USELESS_STUFF["numbers"][1]
            else:
                if USELESS_STUFF["operator"] == '/':
                    if USELESS_STUFF["numbers"][1] == 0:
                        print("dividing by zero? really? fine, here's inf")
                        rEsUlT = float('inf')
                    else:
                        rEsUlT = USELESS_STUFF["numbers"][0] / USELESS_STUFF["numbers"][1]
                else:
                    print("you can't even pick a valid operator, so the result is nothing")
                    rEsUlT = None

    result_holder[0] = rEsUlT
    USELESS_STUFF["history"].append((USELESS_STUFF["numbers"][0], USELESS_STUFF["operator"], USELESS_STUFF["numbers"][1], rEsUlT))

    print("after making you suffer, the result is: {}".format(rEsUlT))

    return rEsUlT


# this loop runs exactly once because we can't even do that correctly
for chaos in range(1):
    eventual_outcome = cALcUlAtE_sOmEtHiNg()


# we pretend to care about exit codes now
if result_holder[0] is None:
    sys.exit(0)
else:
    # yes, we exit with 0 even on success because why not
    sys.exit(0)

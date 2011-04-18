#
# Reference Lister
#
# List all functions and all references to them in the current section.
#
# Implemented with the idautils module
#
from idautils import *

def main():
    # Get current ea
    ea = ScreenEA()
    if ea == idaapi.BADADDR:
        print("Could not get get_screen_ea()")
        return

    # Loop from start to end in the current segment
    for funcea in Functions(SegStart(ea), SegEnd(ea)):
        print("Function %s at 0x%x" % (GetFunctionName(funcea), funcea))

        # Find all code references to funcea
        for ref in CodeRefsTo(funcea, 1):
            print("  called from %s(0x%x)" % (GetFunctionName(ref), ref))


if __name__=='__main__':
    main()
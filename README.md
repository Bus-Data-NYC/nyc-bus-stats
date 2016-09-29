General strategy:
    1. Create a tracking index (`call_increments`) for each observed call in `calls`. This index counts up for each call at a given stop by a given route in a given service.
    2. Join each call to the previous call to get observed headway, also joining to the `schedule` to calculate the average headway for the route during a given hour.

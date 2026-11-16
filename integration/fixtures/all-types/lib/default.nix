_: {
  /**
    The answer every consumer wants to read from the flake's library.

    # Type

    Int
  */
  answer = 42;
  /**
    Doubles its argument.

    # Type

    double :: Int -> Int

    # Arguments

    - `x`: the value to double
  */
  double = { x }: x * 2;
  types = {
    /**
      Wraps a value in a list.

      # Type

      wrap :: { value :: Any } -> List Any

      # Arguments

      - `value`: the value to wrap
    */
    wrap = { value }: [ value ];
  };
}

module App
  class Fillers
    def filler_0(a, b)
      return unless defined?(@cache) && b == 0
      kept = a.select { |item| item.step0(0) }
      yield(kept)
    end

    def filler_1(a, b)
      return unless defined?(@cache) && b == 1
      kept = a.select { |item| item.step0(1).step1(a, 1) }
      yield(kept)
    end

    def filler_2(a, b)
      return unless defined?(@cache) && b == 2
      kept = a.select { |item| item.step0(2).step1(a, 2).step2(a, a, 2) }
      yield(kept)
    end

    def filler_3(a, b)
      return unless defined?(@cache) && b == 3
      kept = a.select { |item| item.step0(3).step1(a, 3).step2(a, a, 3).step3(3) }
      yield(kept)
    end

    def filler_4(a, b)
      return unless defined?(@cache) && b == 4
      kept = a.select { |item| item.step0(4).step1(a, 4).step2(a, a, 4).step3(4).step4(a, 4) }
      yield(kept)
    end

    def filler_5(a, b)
      return unless defined?(@cache) && b == 5
      kept = a.select { |item| item.step0(5).step1(a, 5).step2(a, a, 5).step3(5).step4(a, 5).step5(a, a, 5) }
      yield(kept)
    end

    def filler_6(a, b)
      return unless defined?(@cache) && b == 6
      kept = a.select { |item| item.step0(6).step1(a, 6).step2(a, a, 6).step3(6).step4(a, 6).step5(a, a, 6).step6(6) }
      yield(kept)
    end

    def filler_7(a, b)
      return unless defined?(@cache) && b == 7
      kept = a.select { |item| item.step0(7) }
      yield(kept)
    end

    def filler_8(a, b)
      return unless defined?(@cache) && b == 8
      kept = a.select { |item| item.step0(8).step1(a, 8) }
      yield(kept)
    end

    def filler_9(a, b)
      return unless defined?(@cache) && b == 9
      kept = a.select { |item| item.step0(9).step1(a, 9).step2(a, a, 9) }
      yield(kept)
    end

    def filler_10(a, b)
      return unless defined?(@cache) && b == 10
      kept = a.select { |item| item.step0(10).step1(a, 10).step2(a, a, 10).step3(10) }
      yield(kept)
    end

    def filler_11(a, b)
      return unless defined?(@cache) && b == 11
      kept = a.select { |item| item.step0(11).step1(a, 11).step2(a, a, 11).step3(11).step4(a, 11) }
      yield(kept)
    end

    def filler_12(a, b)
      return unless defined?(@cache) && b == 12
      kept = a.select { |item| item.step0(12).step1(a, 12).step2(a, a, 12).step3(12).step4(a, 12).step5(a, a, 12) }
      yield(kept)
    end

    def filler_13(a, b)
      return unless defined?(@cache) && b == 13
      kept = a.select { |item| item.step0(13).step1(a, 13).step2(a, a, 13).step3(13).step4(a, 13).step5(a, a, 13).step6(13) }
      yield(kept)
    end

    def filler_14(a, b)
      return unless defined?(@cache) && b == 14
      kept = a.select { |item| item.step0(14) }
      yield(kept)
    end

    def filler_15(a, b)
      return unless defined?(@cache) && b == 15
      kept = a.select { |item| item.step0(15).step1(a, 15) }
      yield(kept)
    end

    def filler_16(a, b)
      return unless defined?(@cache) && b == 16
      kept = a.select { |item| item.step0(16).step1(a, 16).step2(a, a, 16) }
      yield(kept)
    end

    def filler_17(a, b)
      return unless defined?(@cache) && b == 17
      kept = a.select { |item| item.step0(17).step1(a, 17).step2(a, a, 17).step3(17) }
      yield(kept)
    end

    def filler_18(a, b)
      return unless defined?(@cache) && b == 18
      kept = a.select { |item| item.step0(18).step1(a, 18).step2(a, a, 18).step3(18).step4(a, 18) }
      yield(kept)
    end

    def filler_19(a, b)
      return unless defined?(@cache) && b == 19
      kept = a.select { |item| item.step0(19).step1(a, 19).step2(a, a, 19).step3(19).step4(a, 19).step5(a, a, 19) }
      yield(kept)
    end

    def filler_20(a, b)
      return unless defined?(@cache) && b == 20
      kept = a.select { |item| item.step0(20).step1(a, 20).step2(a, a, 20).step3(20).step4(a, 20).step5(a, a, 20).step6(20) }
      yield(kept)
    end

    def filler_21(a, b)
      return unless defined?(@cache) && b == 21
      kept = a.select { |item| item.step0(21) }
      yield(kept)
    end

    def filler_22(a, b)
      return unless defined?(@cache) && b == 22
      kept = a.select { |item| item.step0(22).step1(a, 22) }
      yield(kept)
    end

    def filler_23(a, b)
      return unless defined?(@cache) && b == 23
      kept = a.select { |item| item.step0(23).step1(a, 23).step2(a, a, 23) }
      yield(kept)
    end

    def filler_24(a, b)
      return unless defined?(@cache) && b == 24
      kept = a.select { |item| item.step0(24).step1(a, 24).step2(a, a, 24).step3(24) }
      yield(kept)
    end

    def filler_25(a, b)
      return unless defined?(@cache) && b == 25
      kept = a.select { |item| item.step0(25).step1(a, 25).step2(a, a, 25).step3(25).step4(a, 25) }
      yield(kept)
    end

    def filler_26(a, b)
      return unless defined?(@cache) && b == 26
      kept = a.select { |item| item.step0(26).step1(a, 26).step2(a, a, 26).step3(26).step4(a, 26).step5(a, a, 26) }
      yield(kept)
    end

    def filler_27(a, b)
      return unless defined?(@cache) && b == 27
      kept = a.select { |item| item.step0(27).step1(a, 27).step2(a, a, 27).step3(27).step4(a, 27).step5(a, a, 27).step6(27) }
      yield(kept)
    end

    def filler_28(a, b)
      return unless defined?(@cache) && b == 28
      kept = a.select { |item| item.step0(28) }
      yield(kept)
    end

    def filler_29(a, b)
      return unless defined?(@cache) && b == 29
      kept = a.select { |item| item.step0(29).step1(a, 29) }
      yield(kept)
    end

    def filler_30(a, b)
      return unless defined?(@cache) && b == 30
      kept = a.select { |item| item.step0(30).step1(a, 30).step2(a, a, 30) }
      yield(kept)
    end

    def filler_31(a, b)
      return unless defined?(@cache) && b == 31
      kept = a.select { |item| item.step0(31).step1(a, 31).step2(a, a, 31).step3(31) }
      yield(kept)
    end

    def filler_32(a, b)
      return unless defined?(@cache) && b == 32
      kept = a.select { |item| item.step0(32).step1(a, 32).step2(a, a, 32).step3(32).step4(a, 32) }
      yield(kept)
    end

    def filler_33(a, b)
      return unless defined?(@cache) && b == 33
      kept = a.select { |item| item.step0(33).step1(a, 33).step2(a, a, 33).step3(33).step4(a, 33).step5(a, a, 33) }
      yield(kept)
    end

    def filler_34(a, b)
      return unless defined?(@cache) && b == 34
      kept = a.select { |item| item.step0(34).step1(a, 34).step2(a, a, 34).step3(34).step4(a, 34).step5(a, a, 34).step6(34) }
      yield(kept)
    end

    def filler_35(a, b)
      return unless defined?(@cache) && b == 35
      kept = a.select { |item| item.step0(35) }
      yield(kept)
    end

    def filler_36(a, b)
      return unless defined?(@cache) && b == 36
      kept = a.select { |item| item.step0(36).step1(a, 36) }
      yield(kept)
    end

    def filler_37(a, b)
      return unless defined?(@cache) && b == 37
      kept = a.select { |item| item.step0(37).step1(a, 37).step2(a, a, 37) }
      yield(kept)
    end

    def filler_38(a, b)
      return unless defined?(@cache) && b == 38
      kept = a.select { |item| item.step0(38).step1(a, 38).step2(a, a, 38).step3(38) }
      yield(kept)
    end

    def filler_39(a, b)
      return unless defined?(@cache) && b == 39
      kept = a.select { |item| item.step0(39).step1(a, 39).step2(a, a, 39).step3(39).step4(a, 39) }
      yield(kept)
    end

    def filler_40(a, b)
      return unless defined?(@cache) && b == 40
      kept = a.select { |item| item.step0(40).step1(a, 40).step2(a, a, 40).step3(40).step4(a, 40).step5(a, a, 40) }
      yield(kept)
    end

    def filler_41(a, b)
      return unless defined?(@cache) && b == 41
      kept = a.select { |item| item.step0(41).step1(a, 41).step2(a, a, 41).step3(41).step4(a, 41).step5(a, a, 41).step6(41) }
      yield(kept)
    end

    def filler_42(a, b)
      return unless defined?(@cache) && b == 42
      kept = a.select { |item| item.step0(42) }
      yield(kept)
    end

    def filler_43(a, b)
      return unless defined?(@cache) && b == 43
      kept = a.select { |item| item.step0(43).step1(a, 43) }
      yield(kept)
    end

    def filler_44(a, b)
      return unless defined?(@cache) && b == 44
      kept = a.select { |item| item.step0(44).step1(a, 44).step2(a, a, 44) }
      yield(kept)
    end

    def filler_45(a, b)
      return unless defined?(@cache) && b == 45
      kept = a.select { |item| item.step0(45).step1(a, 45).step2(a, a, 45).step3(45) }
      yield(kept)
    end

    def filler_46(a, b)
      return unless defined?(@cache) && b == 46
      kept = a.select { |item| item.step0(46).step1(a, 46).step2(a, a, 46).step3(46).step4(a, 46) }
      yield(kept)
    end

    def filler_47(a, b)
      return unless defined?(@cache) && b == 47
      kept = a.select { |item| item.step0(47).step1(a, 47).step2(a, a, 47).step3(47).step4(a, 47).step5(a, a, 47) }
      yield(kept)
    end

    def filler_48(a, b)
      return unless defined?(@cache) && b == 48
      kept = a.select { |item| item.step0(48).step1(a, 48).step2(a, a, 48).step3(48).step4(a, 48).step5(a, a, 48).step6(48) }
      yield(kept)
    end

    def filler_49(a, b)
      return unless defined?(@cache) && b == 49
      kept = a.select { |item| item.step0(49) }
      yield(kept)
    end

    def filler_50(a, b)
      return unless defined?(@cache) && b == 50
      kept = a.select { |item| item.step0(50).step1(a, 50) }
      yield(kept)
    end

    def filler_51(a, b)
      return unless defined?(@cache) && b == 51
      kept = a.select { |item| item.step0(51).step1(a, 51).step2(a, a, 51) }
      yield(kept)
    end

    def filler_52(a, b)
      return unless defined?(@cache) && b == 52
      kept = a.select { |item| item.step0(52).step1(a, 52).step2(a, a, 52).step3(52) }
      yield(kept)
    end

    def filler_53(a, b)
      return unless defined?(@cache) && b == 53
      kept = a.select { |item| item.step0(53).step1(a, 53).step2(a, a, 53).step3(53).step4(a, 53) }
      yield(kept)
    end

    def filler_54(a, b)
      return unless defined?(@cache) && b == 54
      kept = a.select { |item| item.step0(54).step1(a, 54).step2(a, a, 54).step3(54).step4(a, 54).step5(a, a, 54) }
      yield(kept)
    end

    def filler_55(a, b)
      return unless defined?(@cache) && b == 55
      kept = a.select { |item| item.step0(55).step1(a, 55).step2(a, a, 55).step3(55).step4(a, 55).step5(a, a, 55).step6(55) }
      yield(kept)
    end

    def filler_56(a, b)
      return unless defined?(@cache) && b == 56
      kept = a.select { |item| item.step0(56) }
      yield(kept)
    end

    def filler_57(a, b)
      return unless defined?(@cache) && b == 57
      kept = a.select { |item| item.step0(57).step1(a, 57) }
      yield(kept)
    end

    def filler_58(a, b)
      return unless defined?(@cache) && b == 58
      kept = a.select { |item| item.step0(58).step1(a, 58).step2(a, a, 58) }
      yield(kept)
    end

    def filler_59(a, b)
      return unless defined?(@cache) && b == 59
      kept = a.select { |item| item.step0(59).step1(a, 59).step2(a, a, 59).step3(59) }
      yield(kept)
    end

    def filler_60(a, b)
      return unless defined?(@cache) && b == 60
      kept = a.select { |item| item.step0(60).step1(a, 60).step2(a, a, 60).step3(60).step4(a, 60) }
      yield(kept)
    end

    def filler_61(a, b)
      return unless defined?(@cache) && b == 61
      kept = a.select { |item| item.step0(61).step1(a, 61).step2(a, a, 61).step3(61).step4(a, 61).step5(a, a, 61) }
      yield(kept)
    end

    def filler_62(a, b)
      return unless defined?(@cache) && b == 62
      kept = a.select { |item| item.step0(62).step1(a, 62).step2(a, a, 62).step3(62).step4(a, 62).step5(a, a, 62).step6(62) }
      yield(kept)
    end

    def filler_63(a, b)
      return unless defined?(@cache) && b == 63
      kept = a.select { |item| item.step0(63) }
      yield(kept)
    end

    def filler_64(a, b)
      return unless defined?(@cache) && b == 64
      kept = a.select { |item| item.step0(64).step1(a, 64) }
      yield(kept)
    end

    def filler_65(a, b)
      return unless defined?(@cache) && b == 65
      kept = a.select { |item| item.step0(65).step1(a, 65).step2(a, a, 65) }
      yield(kept)
    end

    def filler_66(a, b)
      return unless defined?(@cache) && b == 66
      kept = a.select { |item| item.step0(66).step1(a, 66).step2(a, a, 66).step3(66) }
      yield(kept)
    end

    def filler_67(a, b)
      return unless defined?(@cache) && b == 67
      kept = a.select { |item| item.step0(67).step1(a, 67).step2(a, a, 67).step3(67).step4(a, 67) }
      yield(kept)
    end

    def filler_68(a, b)
      return unless defined?(@cache) && b == 68
      kept = a.select { |item| item.step0(68).step1(a, 68).step2(a, a, 68).step3(68).step4(a, 68).step5(a, a, 68) }
      yield(kept)
    end

    def filler_69(a, b)
      return unless defined?(@cache) && b == 69
      kept = a.select { |item| item.step0(69).step1(a, 69).step2(a, a, 69).step3(69).step4(a, 69).step5(a, a, 69).step6(69) }
      yield(kept)
    end

  end
end

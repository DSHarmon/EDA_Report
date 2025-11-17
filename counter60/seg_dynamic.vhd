library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity seg_dynamic is
    port (
        sys_clk   : in  std_logic;
        sys_rst_n : in  std_logic;
        data      : in  unsigned(6 downto 0); -- 输入为 0-60 的无符号数
        point     : in  std_logic_vector(5 downto 0); -- 小数点控制（暂用）
        seg_en    : in  std_logic; -- 显示使能（1=显示）
        sign      : in  std_logic; -- 符号位（暂用）
        sel       : out std_logic_vector(5 downto 0); -- 位选输出（6个数码管，共阴高电平选中）
        seg       : out std_logic_vector(7 downto 0) -- 段选输出（a~dp，共阴高电平点亮）
    );
end entity seg_dynamic;

architecture Behavioral of seg_dynamic is

    -- ========================== 共阴数码管段码表（高电平点亮）==========================
    constant SEG_0 : std_logic_vector(6 downto 0) := "1000000"; -- 0
    constant SEG_1 : std_logic_vector(6 downto 0) := "1111001"; -- 1
    constant SEG_2 : std_logic_vector(6 downto 0) := "0100100"; -- 2
    constant SEG_3 : std_logic_vector(6 downto 0) := "0110000"; -- 3
    constant SEG_4 : std_logic_vector(6 downto 0) := "0011001"; -- 4
    constant SEG_5 : std_logic_vector(6 downto 0) := "0010010"; -- 5
    constant SEG_6 : std_logic_vector(6 downto 0) := "0000010"; -- 6
    constant SEG_7 : std_logic_vector(6 downto 0) := "1111000"; -- 7
    constant SEG_8 : std_logic_vector(6 downto 0) := "0000000"; -- 8
    constant SEG_9 : std_logic_vector(6 downto 0) := "0010000"; -- 9
    constant SEG_OFF : std_logic_vector(7 downto 0) := "11111111"; -- 全灭

    -- 常量定义
    constant CNT_MAX : unsigned(15 downto 0) := to_unsigned(49999, 16); -- 50MHz时钟下1ms计数

    -- 内部信号声明
    signal cnt_1ms       : unsigned(15 downto 0);
    signal flag_1ms      : std_logic;
    signal cnt_sel       : unsigned(2 downto 0); -- 位选计数器
    signal sel_reg       : std_logic_vector(5 downto 0); -- 位选寄存器
    signal data_disp     : std_logic_vector(3 downto 0); -- 当前显示的数字
    signal dot_disp      : std_logic; -- 当前显示的小数点

    -- 个位和十位
    signal digit_ones    : unsigned(3 downto 0); -- 个位数 (0-9)
    signal digit_tens    : unsigned(3 downto 0); -- 十位数 (0-6)

begin

    -- =============================================================================
    -- 1. 计算个位和十位
    -- =============================================================================
    digit_ones <= resize(data mod 10, 4);
    digit_tens <= resize(data / 10, 4);

    -- =============================================================================
    -- 2. 1ms 计数器和标志信号 (使用 if-else 修正语法错误)
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            cnt_1ms <= (others => '0');
        elsif rising_edge(sys_clk) then
            if cnt_1ms = CNT_MAX then
                cnt_1ms <= (others => '0');
            else
                cnt_1ms <= cnt_1ms + 1;
            end if;
        end if;
    end process;

    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            flag_1ms <= '0';
        elsif rising_edge(sys_clk) then
            -- 使用 if-else 替代 when-else，以兼容所有 VHDL 版本
            if cnt_1ms = CNT_MAX - 1 then
                flag_1ms <= '1';
            else
                flag_1ms <= '0';
            end if;
        end if;
    end process;

    -- =============================================================================
    -- 3. 位选计数器：仅在 "100"(4) 和 "101"(5) 之间循环
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            cnt_sel <= "100"; -- 初始值=4
        elsif rising_edge(sys_clk) and flag_1ms = '1' then
            if cnt_sel = "101" then -- 比较：cnt_sel vs 二进制"101"(5)
                cnt_sel <= "100"; -- 从5→4
            else
                cnt_sel <= cnt_sel + 1; -- 从4→5
            end if;
        end if;
    end process;

    -- =============================================================================
    -- 4. 位选信号生成：仅最后两个数码管轮流点亮
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            sel_reg <= "000000";
        elsif rising_edge(sys_clk) then
            case cnt_sel is
                when "100" => sel_reg <= "000010"; -- 倒数第二个数码管（十位）选中
                when "101" => sel_reg <= "000001"; -- 最后一个数码管（个位）选中
                when others => sel_reg <= "111111"; -- 其他情况全灭
            end case;
        end if;
    end process;

    -- =============================================================================
    -- 5. 数据选择：根据当前位选，选择显示个位或十位
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            data_disp <= x"0";
        elsif rising_edge(sys_clk) then
            if seg_en = '1' then
                case cnt_sel is
                    when "101" => data_disp <= std_logic_vector(digit_ones); -- 个位
                    when "100" => data_disp <= std_logic_vector(digit_tens); -- 十位
                    when others => data_disp <= x"F"; -- 其他情况全灭
                end case;
            else
                data_disp <= x"F"; -- 显示关闭时全灭
            end if;
        end if;
    end process;

    -- =============================================================================
    -- 6. 小数点控制
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            dot_disp <= '0';
        elsif rising_edge(sys_clk) and flag_1ms = '1' then
            if cnt_sel = "100" then -- 十位的小数点
                dot_disp <= point(4);
            elsif cnt_sel = "101" then -- 个位的小数点
                dot_disp <= point(5);
            else
                dot_disp <= '0';
            end if;
        end if;
    end process;

    -- =============================================================================
    -- 7. 段选信号生成
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            seg <= SEG_OFF;
        elsif rising_edge(sys_clk) then
            case data_disp is
                when x"0" => seg <= dot_disp & SEG_0;
                when x"1" => seg <= dot_disp & SEG_1;
                when x"2" => seg <= dot_disp & SEG_2;
                when x"3" => seg <= dot_disp & SEG_3;
                when x"4" => seg <= dot_disp & SEG_4;
                when x"5" => seg <= dot_disp & SEG_5;
                when x"6" => seg <= dot_disp & SEG_6;
                when x"7" => seg <= dot_disp & SEG_7;
                when x"8" => seg <= dot_disp & SEG_8;
                when x"9" => seg <= dot_disp & SEG_9;
                when others => seg <= SEG_OFF; -- 全灭
            end case;
        end if;
    end process;

    -- =============================================================================
    -- 8. 输出赋值
    -- =============================================================================
    sel <= sel_reg;

end architecture Behavioral;
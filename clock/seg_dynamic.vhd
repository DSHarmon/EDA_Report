library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity seg_dynamic is
    port (
        sys_clk   : in  std_logic;
        sys_rst_n : in  std_logic;
        data      : in  unsigned(6 downto 0); -- 保留原有接口以保持兼容性
        point     : in  std_logic_vector(5 downto 0); -- 小数点控制（用于时钟分隔符）
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
    
    -- 时钟数据信号（模拟从data_gen模块获取的时钟数据）
    signal hour          : unsigned(4 downto 0) := "00000"; -- 小时 (0-23)
    signal minute        : unsigned(5 downto 0) := "000000"; -- 分钟 (0-59)
    signal second        : unsigned(5 downto 0) := "000000"; -- 秒 (0-59)
    
    -- 时钟各位数字
    signal hour_tens     : unsigned(3 downto 0); -- 时十位 (0-2)
    signal hour_ones     : unsigned(3 downto 0); -- 时个位 (0-9)
    signal minute_tens   : unsigned(3 downto 0); -- 分十位 (0-5)
    signal minute_ones   : unsigned(3 downto 0); -- 分个位 (0-9)
    signal second_tens   : unsigned(3 downto 0); -- 秒十位 (0-5)
    signal second_ones   : unsigned(3 downto 0); -- 秒个位 (0-9)
    
    -- 测试用计数器，用于在没有实际时钟输入时模拟计时
    signal test_cnt      : unsigned(25 downto 0);

begin
    -- =============================================================================
    -- 测试用：模拟时钟计数（实际项目中应从外部模块获取）
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            test_cnt <= (others => '0');
            second <= (others => '0');
            minute <= (others => '0');
            hour <= (others => '0');
        elsif rising_edge(sys_clk) then
            -- 模拟1秒计数（实际项目中应使用外部时钟输入）
            if test_cnt >= 49999999 then -- 50MHz时钟下1秒
                test_cnt <= (others => '0');
                
                -- 秒计数
                if second = 59 then
                    second <= (others => '0');
                    -- 分计数
                    if minute = 59 then
                        minute <= (others => '0');
                        -- 时计数
                        if hour = 23 then
                            hour <= (others => '0');
                        else
                            hour <= hour + 1;
                        end if;
                    else
                        minute <= minute + 1;
                    end if;
                else
                    second <= second + 1;
                end if;
            else
                test_cnt <= test_cnt + 1;
            end if;
        end if;
    end process;

    -- =============================================================================
    -- 1. 计算时钟各位数字
    -- =============================================================================
    hour_tens   <= resize(hour / 10, 4);
    hour_ones   <= resize(hour mod 10, 4);
    minute_tens <= resize(minute / 10, 4);
    minute_ones <= resize(minute mod 10, 4);
    second_tens <= resize(second / 10, 4);
    second_ones <= resize(second mod 10, 4);

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
    -- 3. 位选计数器：在 0 到 5 之间循环（控制6个数码管）
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            cnt_sel <= "000"; -- 初始值=0
        elsif rising_edge(sys_clk) and flag_1ms = '1' then
            if cnt_sel = "101" then -- 5
                cnt_sel <= "000"; -- 从5→0循环
            else
                cnt_sel <= cnt_sel + 1; -- 递增
            end if;
        end if;
    end process;

    -- =============================================================================
    -- 4. 位选信号生成：6个数码管轮流点亮
    -- 格式：第5位 第4位 第3位 第2位 第1位 第0位
    --      时十  时个  分十  分个  秒十  秒个
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            sel_reg <= "000000";
        elsif rising_edge(sys_clk) then
            case cnt_sel is
                when "000" => sel_reg <= "100000"; -- 第5位：时十位
                when "001" => sel_reg <= "010000"; -- 第4位：时个位
                when "010" => sel_reg <= "001000"; -- 第3位：分十位
                when "011" => sel_reg <= "000100"; -- 第2位：分个位
                when "100" => sel_reg <= "000010"; -- 第1位：秒十位
                when "101" => sel_reg <= "000001"; -- 第0位：秒个位
                when others => sel_reg <= "000000"; -- 其他情况全灭
            end case;
        end if;
    end process;

    -- =============================================================================
    -- 5. 数据选择：根据当前位选，选择显示时钟对应位
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            data_disp <= x"0";
        elsif rising_edge(sys_clk) then
            if seg_en = '1' then
                case cnt_sel is
                    when "000" => data_disp <= std_logic_vector(hour_tens);   -- 时十位
                    when "001" => data_disp <= std_logic_vector(hour_ones);   -- 时个位
                    when "010" => data_disp <= std_logic_vector(minute_tens); -- 分十位
                    when "011" => data_disp <= std_logic_vector(minute_ones); -- 分个位
                    when "100" => data_disp <= std_logic_vector(second_tens); -- 秒十位
                    when "101" => data_disp <= std_logic_vector(second_ones); -- 秒个位
                    when others => data_disp <= x"F"; -- 其他情况全灭
                end case;
            else
                data_disp <= x"F"; -- 显示关闭时全灭
            end if;
        end if;
    end process;

    -- =============================================================================
    -- 6. 小数点控制（作为时钟分隔符）
    -- 在时个位和分十位之间，以及分个位和秒十位之间显示小数点
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            dot_disp <= '0';
        elsif rising_edge(sys_clk) then
            case cnt_sel is
                when "001" => dot_disp <= point(4); -- 时个位的小数点（作为时和分的分隔符）
                when "011" => dot_disp <= point(2); -- 分个位的小数点（作为分和秒的分隔符）
                when others => dot_disp <= '1'; -- 其他位置不显示小数点
            end case;
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
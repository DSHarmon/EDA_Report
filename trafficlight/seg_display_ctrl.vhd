-- 数码管显示控制模块
-- 控制4个数码管显示主干道和支干道的倒计时
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity seg_display_ctrl is
    port (
        sys_clk          : in  std_logic;
        sys_rst_n        : in  std_logic;
        main_countdown   : in  unsigned(5 downto 0);        -- 主干道倒计时（秒）
        branch_countdown : in  unsigned(5 downto 0);        -- 支干道倒计时（秒）
        
        -- 数码管控制信号
        seg_stcp         : out std_logic;
        seg_shcp         : out std_logic;
        seg_ds           : out std_logic;
        seg_oe           : out std_logic
    );
end entity seg_display_ctrl;

architecture Behavioral of seg_display_ctrl is
    -- 数码管位选信号（4个数码管）
    type seg_select is (MAIN_TENS, MAIN_ONES, BRANCH_TENS, BRANCH_ONES);
    
    -- 共阳数码管段码表（标准定义）
    type seg_code is array (0 to 10) of std_logic_vector(6 downto 0);
    constant SEG_TABLE : seg_code := (
        "1000000", -- 0
        "1111001", -- 1
        "0100100", -- 2
        "0110000", -- 3
        "0011001", -- 4
        "0010010", -- 5
        "0000010", -- 6
        "1111000", -- 7
        "0000000", -- 8
        "0010000", -- 9
        "0111111"   -- 10: 横杠 '-'（G段熄灭，其余点亮）
    );
    
    -- 内部信号
    signal sel_state   : seg_select := MAIN_TENS;
    signal seg_data    : std_logic_vector(7 downto 0);
    signal seg_sel     : std_logic_vector(5 downto 0);  
    
    -- 74HC595控制信号
    signal data        : std_logic_vector(13 downto 0); -- 14位数据：8位段选 + 6位位选
    signal cnt_4       : unsigned(1 downto 0);          -- 分频计数器 (0-3)
    signal cnt_bit     : unsigned(3 downto 0);          -- 传输位数计数器 (0-13)
    
    -- 数据分解
    signal main_tens_sig   : unsigned(3 downto 0);
    signal main_ones_sig   : unsigned(3 downto 0);
    signal branch_tens_sig : unsigned(3 downto 0);
    signal branch_ones_sig : unsigned(3 downto 0);
    
begin
    -- 1. 分解倒计时数据为十位和个位
    branch_tens_sig   <= resize(main_countdown / 10, 4);
    branch_ones_sig   <= resize(main_countdown mod 10, 4);
    main_tens_sig <= resize(branch_countdown / 10, 4);
    main_ones_sig <= resize(branch_countdown mod 10, 4);
    
    -- 2. 数码管动态扫描
    process(sys_clk, sys_rst_n)
        variable cnt : unsigned(15 downto 0) := (others => '0');
    begin
        if sys_rst_n = '0' then
            cnt := (others => '0');
            sel_state <= MAIN_TENS;
        elsif rising_edge(sys_clk) then
            cnt := cnt + 1;
            if cnt = to_unsigned(49999, 16) then -- 1ms扫描间隔
                cnt := (others => '0');
                case sel_state is
                    when MAIN_TENS =>
                        sel_state <= MAIN_ONES;
                        seg_sel <= "000001";  -- 高电平有效，选中第一个数码管（扩展为6位）
                        if main_countdown = 0 and branch_countdown = 0 then
                            -- 模式1：显示横杠
                            seg_data <= '1' & SEG_TABLE(10);
                        else
                            -- 模式2和3：显示倒计时 - 交换十位和个位
                            seg_data <= '1' & SEG_TABLE(to_integer(main_ones_sig));
                        end if;
                    when MAIN_ONES =>
                        sel_state <= BRANCH_TENS;
                        seg_sel <= "000010";  -- 高电平有效，选中第二个数码管（扩展为6位）
                        if main_countdown = 0 and branch_countdown = 0 then
                            -- 模式1：显示横杠
                            seg_data <= '1' & SEG_TABLE(10);
                        else
                            -- 模式2和3：显示倒计时 - 交换十位和个位
                            seg_data <= '1' & SEG_TABLE(to_integer(main_tens_sig));
                        end if;
                    when BRANCH_TENS =>
                        sel_state <= BRANCH_ONES;
                        seg_sel <= "000100";  -- 高电平有效，选中第三个数码管（扩展为6位）
                        if main_countdown = 0 and branch_countdown = 0 then
                            -- 模式1：显示横杠
                            seg_data <= '1' & SEG_TABLE(10);
                        else
                            -- 模式2和3：显示倒计时 - 交换十位和个位
                            seg_data <= '1' & SEG_TABLE(to_integer(branch_ones_sig));
                        end if;
                    when BRANCH_ONES =>
                        sel_state <= MAIN_TENS;
                        seg_sel <= "001000";  -- 高电平有效，选中第四个数码管（扩展为6位）
                        if main_countdown = 0 and branch_countdown = 0 then
                            -- 模式1：显示横杠
                            seg_data <= '1' & SEG_TABLE(10);
                        else
                            -- 模式2和3：显示倒计时 - 交换十位和个位
                            seg_data <= '1' & SEG_TABLE(to_integer(branch_tens_sig));
                        end if;
                end case;
            end if;
        end if;
    end process;
    
    -- 3. 74HC595数据拼接（与hc595_ctrl保持一致的位顺序）
    -- 将数码管信号（段选 + 位选）拼接成一个14位的串行数据流
    data <= seg_data(0) & seg_data(1) & seg_data(2) & seg_data(3) & seg_data(4) & seg_data(5) & seg_data(6) & seg_data(7) & seg_sel;
    
    -- 4. 分频计数器（与hc595_ctrl保持一致）
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            cnt_4 <= (others => '0');
        elsif rising_edge(sys_clk) then
            if cnt_4 = to_unsigned(3, cnt_4'length) then
                cnt_4 <= (others => '0');
            else
                cnt_4 <= cnt_4 + 1;
            end if;
        end if;
    end process;
    
    -- 5. 传输位数计数器（与hc595_ctrl保持一致）
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            cnt_bit <= (others => '0');
        elsif rising_edge(sys_clk) then
            if cnt_4 = to_unsigned(3, cnt_4'length) then
                if cnt_bit = to_unsigned(13, cnt_bit'length) then
                    cnt_bit <= (others => '0');
                else
                    cnt_bit <= cnt_bit + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- 6. 存储寄存器时钟（与hc595_ctrl保持一致）
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            seg_stcp <= '0';
        elsif rising_edge(sys_clk) then
            if (cnt_bit = to_unsigned(13, cnt_bit'length)) and (cnt_4 = to_unsigned(3, cnt_4'length)) then
                seg_stcp <= '1';
            else
                seg_stcp <= '0';
            end if;
        end if;
    end process;
    
    -- 7. 移位寄存器时钟（与hc595_ctrl保持一致）
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            seg_shcp <= '0';
        elsif rising_edge(sys_clk) then
            if cnt_4 >= to_unsigned(2, cnt_4'length) then
                seg_shcp <= '1';
            else
                seg_shcp <= '0';
            end if;
        end if;
    end process;
    
    -- 8. 串行数据输出（与hc595_ctrl保持一致）
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            seg_ds <= '0';
        elsif rising_edge(sys_clk) then
            if cnt_4 = to_unsigned(0, cnt_4'length) then
                seg_ds <= data(to_integer(cnt_bit));
            end if;
        end if;
    end process;
    
    -- 9. 输出使能（与hc595_ctrl保持一致）
    seg_oe <= not sys_rst_n;
    
end architecture Behavioral;
-- 按钮消抖模块
-- 检测按钮下降沿并输出稳定的触发信号
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity btn_debounce is
    port (
        sys_clk          : in  std_logic;
        sys_rst_n        : in  std_logic;
        btn_in           : in  std_logic;
        btn_out          : out std_logic;
        btn_edge         : out std_logic
    );
end entity btn_debounce;

architecture Behavioral of btn_debounce is
    -- 内部信号
    signal btn_sync    : std_logic_vector(1 downto 0) := "11";
    signal btn_deb     : std_logic := '1';
    signal btn_prev    : std_logic := '1';
    signal cnt_debounce: unsigned(17 downto 0) := (others => '0');
    
begin
    -- 1. 输入同步
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            btn_sync <= "11";
        elsif rising_edge(sys_clk) then
            btn_sync <= btn_sync(0) & btn_in;
        end if;
    end process;
    
    -- 2. 消抖逻辑
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            btn_deb <= '1';
            cnt_debounce <= (others => '0');
        elsif rising_edge(sys_clk) then
            if btn_sync(1) /= btn_deb then
                cnt_debounce <= cnt_debounce + 1;
                if cnt_debounce = to_unsigned(499999, 18) then -- 10ms消抖
                    btn_deb <= btn_sync(1);
                    cnt_debounce <= (others => '0');
                end if;
            else
                cnt_debounce <= (others => '0');
            end if;
        end if;
    end process;
    
    -- 3. 边沿检测
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            btn_prev <= '1';
            btn_edge <= '0';
        elsif rising_edge(sys_clk) then
            btn_prev <= btn_deb;
            if btn_prev = '1' and btn_deb = '0' then
                btn_edge <= '1';
            else
                btn_edge <= '0';
            end if;
        end if;
    end process;
    
    -- 输出赋值
    btn_out <= btn_deb;
    
end architecture Behavioral;